import AppKit
import SwiftUI

struct WorkspaceEntry: Identifiable, Hashable {
    let url: URL
    let isDirectory: Bool

    var id: URL { url }
    var name: String { url.lastPathComponent }
}

/// The folder opened as a workspace and the files it contains.
///
/// Folders are read on demand as they are expanded, so opening a workspace
/// with a large tree stays fast.
@MainActor
final class Workspace: ObservableObject {
    static let rootsDefaultsKey = "CodePad16.workspaceRoots"
    private static let legacyRootDefaultsKey = "CodePad16.workspaceRoot"

    @Published private(set) var roots: [URL] = []
    @Published private(set) var expanded: Set<URL> = []
    private var childCache: [URL: [WorkspaceEntry]] = [:]

    init() {
        let defaults = UserDefaults.standard
        var paths = defaults.stringArray(forKey: Self.rootsDefaultsKey) ?? []
        if paths.isEmpty, let legacy = defaults.string(forKey: Self.legacyRootDefaultsKey) {
            paths = [legacy]
            defaults.removeObject(forKey: Self.legacyRootDefaultsKey)
            defaults.set(paths, forKey: Self.rootsDefaultsKey)
        }

        let existing = paths.map {
            URL(fileURLWithPath: $0).standardizedFileURL
        }.filter { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }

        roots = existing
        expanded = Set(existing)
        if existing.count != paths.count { persist() }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Add to Workspace"
        panel.message = "Choose one or more folders to add to the workspace."
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { open(url) }
    }

    func open(_ folder: URL) {
        let url = folder.standardizedFileURL
        guard !roots.contains(url) else {
            expanded.insert(url)
            return
        }
        roots.append(url)
        expanded.insert(url)
        persist()
    }

    func remove(_ folder: URL) {
        let url = folder.standardizedFileURL
        roots.removeAll { $0 == url }
        expanded.remove(url)
        childCache.removeAll()
        persist()
    }

    func close() {
        roots.removeAll()
        expanded.removeAll()
        childCache.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.rootsDefaultsKey)
    }

    private func persist() {
        UserDefaults.standard.set(roots.map(\.path), forKey: Self.rootsDefaultsKey)
    }

    func isExpanded(_ url: URL) -> Bool {
        expanded.contains(url)
    }

    func toggle(_ url: URL) {
        if expanded.contains(url) {
            expanded.remove(url)
        } else {
            expanded.insert(url)
        }
    }

    /// Re-reads every folder the next time it is drawn.
    func reload() {
        childCache.removeAll()
        objectWillChange.send()
    }

    func entries(in directory: URL) -> [WorkspaceEntry] {
        if let cached = childCache[directory] { return cached }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .isPackageKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )) ?? []

        let entries = urls
            .compactMap { url -> WorkspaceEntry? in
                guard let values = try? url.resourceValues(forKeys: keys),
                      values.isSymbolicLink != true,
                      values.isPackage != true else {
                    return nil
                }
                return WorkspaceEntry(url: url, isDirectory: values.isDirectory == true)
            }
            .sorted { left, right in
                if left.isDirectory != right.isDirectory { return left.isDirectory }
                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }

        childCache[directory] = entries
        return entries
    }
}

struct WorkspaceSidebar: View {
    @ObservedObject var workspace: Workspace
    let onOpenFile: (URL) -> Void
    let onSave: (URL) -> Void
    let onSaveAs: (URL) -> Void
    let onSaveCopy: (URL) -> Void
    let onRenameFile: (URL) -> Void
    let onCloseFile: (URL) -> Void
    let isFileOpen: (URL) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(workspace.roots, id: \.self) { root in
                            WorkspaceRootSection(
                                root: root,
                                workspace: workspace,
                                minWidth: proxy.size.width,
                                onOpenFile: onOpenFile,
                                onSave: onSave,
                                onSaveAs: onSaveAs,
                                onSaveCopy: onSaveCopy,
                                onRenameFile: onRenameFile,
                                onCloseFile: onCloseFile,
                                isFileOpen: isFileOpen
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .frame(minWidth: 120, idealWidth: 120, maxWidth: 400)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text("Workspaces")
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
            Button { workspace.chooseFolder() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Add a folder to the workspace")
            Menu {
                Button { workspace.chooseFolder() } label: {
                    Label("Add Folder…", systemImage: "plus")
                }
                Button { workspace.reload() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                if let first = workspace.roots.first {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([first])
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                }
                Divider()
                Button { workspace.close() } label: {
                    Label("Close All Workspaces", systemImage: "xmark.circle")
                }
                .disabled(workspace.roots.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 11, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Workspace actions")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }
}

private struct WorkspaceRootSection: View {
    let root: URL
    @ObservedObject var workspace: Workspace
    let minWidth: CGFloat
    let onOpenFile: (URL) -> Void
    let onSave: (URL) -> Void
    let onSaveAs: (URL) -> Void
    let onSaveCopy: (URL) -> Void
    let onRenameFile: (URL) -> Void
    let onCloseFile: (URL) -> Void
    let isFileOpen: (URL) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Button { workspace.toggle(root) } label: {
                    HStack(spacing: 5) {
                        Image(
                            systemName: workspace.isExpanded(root)
                                ? "chevron.down"
                                : "chevron.right"
                        )
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 14)
                        Text(root.lastPathComponent)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 4)
                    .frame(height: 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(root.path)

                Button { workspace.remove(root) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Remove this folder from the workspace")
            }
            .contextMenu {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([root])
                }
            }
            .frame(minWidth: minWidth, alignment: .leading)

            if workspace.isExpanded(root) {
                let items = workspace.entries(in: root)
                if items.isEmpty {
                    Text("Empty folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 34)
                        .padding(.vertical, 4)
                } else {
                    ForEach(items) { entry in
                        WorkspaceNodeRow(
                            entry: entry,
                            depth: 1,
                            workspace: workspace,
                            minWidth: minWidth,
                            onOpenFile: onOpenFile,
                            onSave: onSave,
                            onSaveAs: onSaveAs,
                            onSaveCopy: onSaveCopy,
                            onRenameFile: onRenameFile,
                            onCloseFile: onCloseFile,
                            isFileOpen: isFileOpen
                        )
                    }
                }
            }
        }
    }
}

private struct WorkspaceNodeRow: View {
    let entry: WorkspaceEntry
    let depth: Int
    @ObservedObject var workspace: Workspace
    let minWidth: CGFloat
    let onOpenFile: (URL) -> Void
    let onSave: (URL) -> Void
    let onSaveAs: (URL) -> Void
    let onSaveCopy: (URL) -> Void
    let onRenameFile: (URL) -> Void
    let onCloseFile: (URL) -> Void
    let isFileOpen: (URL) -> Bool

    var body: some View {
        if entry.isDirectory {
            VStack(alignment: .leading, spacing: 0) {
                row(
                    chevron: workspace.isExpanded(entry.url) ? "chevron.down" : "chevron.right",
                    icon: "folder"
                ) {
                    workspace.toggle(entry.url)
                }
                .contextMenu {
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                    }
                }

                if workspace.isExpanded(entry.url) {
                    ForEach(workspace.entries(in: entry.url)) { child in
                        WorkspaceNodeRow(
                            entry: child,
                            depth: depth + 1,
                            workspace: workspace,
                            minWidth: minWidth,
                            onOpenFile: onOpenFile,
                            onSave: onSave,
                            onSaveAs: onSaveAs,
                            onSaveCopy: onSaveCopy,
                            onRenameFile: onRenameFile,
                            onCloseFile: onCloseFile,
                            isFileOpen: isFileOpen
                        )
                    }
                }
            }
        } else {
            row(chevron: nil, icon: "doc.text") {
                onOpenFile(entry.url)
            }
            .contextMenu {
                Button("Open") { onOpenFile(entry.url) }
                Button("Save") { onSave(entry.url) }
                    .disabled(!isFileOpen(entry.url))
                Button("Save As…") { onSaveAs(entry.url) }
                    .disabled(!isFileOpen(entry.url))
                Button("Save a Copy As…") { onSaveCopy(entry.url) }
                Button("Rename…") { onRenameFile(entry.url) }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([entry.url])
                }
                Divider()
                Button("Close Tab") { onCloseFile(entry.url) }
                    .disabled(!isFileOpen(entry.url))
            }
        }
    }

    private func row(
        chevron: String?,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: chevron ?? "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
                    .opacity(chevron == nil ? 0 : 1)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14)
                Text(entry.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(depth) * 13 + 6)
            .padding(.trailing, 8)
            .frame(height: 22)
            .frame(minWidth: minWidth, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(entry.url.path)
    }
}
