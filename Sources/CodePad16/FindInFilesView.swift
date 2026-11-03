import AppKit
import SwiftUI

/// Find in Files panel, modeled on Notepad++'s search across a folder.
struct FindInFilesView: View {
    let onClose: () -> Void
    let onOpen: (URL, Int) -> Void

    @StateObject private var model = FindInFilesModel()
    @StateObject private var collapse = FileCollapseState()

    var body: some View {
        VStack(spacing: 0) {
            folderRow
            searchRow
            Divider()
            results
            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 360)
        .onDisappear { model.cancel() }
        .onChange(of: model.results.map(\.id)) { _ in
            collapse.reset()
        }
    }

    private var folderRow: some View {
        HStack(spacing: 8) {
            Button("Choose Folder…") { model.chooseFolder() }
            Text(model.folder?.path ?? "No folder selected")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private var searchRow: some View {
        HStack(spacing: 8) {
            TextField("Find in files", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.search() }
            Toggle("Match case", isOn: $model.matchCase)
                .toggleStyle(.checkbox)
            Button("Search") { model.search() }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isSearching)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var results: some View {
        if model.isSearching {
            VStack(spacing: 10) {
                ProgressView()
                Text("Searching…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.results.isEmpty {
            Text(model.status)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(model.results) { file in
                        fileHeader(file)
                        if !collapse.contains(file.url) {
                            ForEach(file.matches) { match in
                                resultRow(file: file, match: match)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func fileHeader(_ file: FileMatches) -> some View {
        Button {
            collapse.toggle(file.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: collapse.contains(file.url) ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
                Text(relativePath(for: file.url))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Text("\(file.matches.count)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.secondary.opacity(0.15)))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .buttonStyle(.plain)
        .help(collapse.contains(file.url) ? "Expand file results" : "Collapse file results")
    }

    private func resultRow(file: FileMatches, match: FileMatch) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(match.line)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
            Text(match.text)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .gesture(
            TapGesture(count: 2)
                .onEnded { onOpen(file.url, match.line) }
                .exclusively(
                    before: TapGesture(count: 1)
                        .onEnded { onOpen(file.url, match.line) }
                )
        )
        .help("Open \(file.url.lastPathComponent) at line \(match.line)")
    }

    private var footer: some View {
        HStack {
            Text(model.status)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !model.results.isEmpty {
                Button(collapse.allCollapsed(model.results.map(\.id)) ? "Expand All" : "Collapse All") {
                    collapse.setAll(model.results.map(\.id), collapsed: !collapse.allCollapsed(model.results.map(\.id)))
                }
                .buttonStyle(.borderless)
            }
            Button("Close", action: onClose)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func relativePath(for url: URL) -> String {
        guard let folder = model.folder else { return url.lastPathComponent }
        let base = folder.path.hasSuffix("/") ? folder.path : folder.path + "/"
        return url.path.hasPrefix(base) ? String(url.path.dropFirst(base.count)) : url.path
    }
}

struct FileMatch: Identifiable {
    let id = UUID()
    let line: Int
    let text: String
}

struct FileMatches: Identifiable {
    let url: URL
    let matches: [FileMatch]

    var id: URL { url }
}

@MainActor
final class FileCollapseState: ObservableObject {
    @Published private(set) var collapsedFiles: Set<URL> = []

    func contains(_ url: URL) -> Bool {
        collapsedFiles.contains(url)
    }

    func toggle(_ url: URL) {
        if collapsedFiles.contains(url) {
            collapsedFiles.remove(url)
        } else {
            collapsedFiles.insert(url)
        }
    }

    func reset() {
        collapsedFiles.removeAll()
    }

    func allCollapsed(_ urls: [URL]) -> Bool {
        !urls.isEmpty && urls.allSatisfy { collapsedFiles.contains($0) }
    }

    func setAll(_ urls: [URL], collapsed: Bool) {
        if collapsed {
            collapsedFiles.formUnion(urls)
        } else {
            collapsedFiles.subtract(urls)
        }
    }
}

@MainActor
final class FindInFilesModel: ObservableObject {
    @Published var folder: URL?
    @Published var query = ""
    @Published var matchCase = false
    @Published var results: [FileMatches] = []
    @Published var isSearching = false
    @Published var status = "Choose a folder and enter a search term."

    private var searchTask: Task<Void, Never>?

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folder = url
        status = "Ready to search \(url.lastPathComponent)."
    }

    func cancel() {
        searchTask?.cancel()
    }

    func search() {
        let term = query
        guard !term.isEmpty else {
            status = "Enter a search term."
            return
        }
        guard let root = folder else {
            status = "Choose a folder first."
            return
        }

        searchTask?.cancel()
        isSearching = true
        results = []
        status = "Searching…"

        let caseSensitive = matchCase
        searchTask = Task {
            let found = await Task.detached(priority: .userInitiated) {
                Self.find(term, in: root, matchCase: caseSensitive)
            }.value
            guard !Task.isCancelled else { return }
            let matchCount = found.reduce(0) { $0 + $1.matches.count }
            results = found
            isSearching = false
            status = matchCount == 0
                ? "No matches"
                : "\(matchCount) match\(matchCount == 1 ? "" : "es") in \(found.count) file\(found.count == 1 ? "" : "s")"
        }
    }

    nonisolated private static func find(
        _ term: String,
        in root: URL,
        matchCase: Bool
    ) -> [FileMatches] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let skippedNames: Set<String> = [
            ".git", ".build", "node_modules", "Pods", "DerivedData", "build", "dist", ".cache"
        ]
        let options: String.CompareOptions = matchCase ? [] : [.caseInsensitive]
        let maximumFileSize = 5 * 1024 * 1024
        let maximumMatches = 1000
        var files: [FileMatches] = []
        var total = 0

        for case let url as URL in enumerator {
            if total >= maximumMatches { break }

            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isDirectory == true {
                if skippedNames.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values?.isRegularFile == true,
                  (values?.fileSize ?? 0) <= maximumFileSize,
                  let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8) else {
                continue
            }

            var matches: [FileMatch] = []
            var lineNumber = 0
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                lineNumber += 1
                guard total < maximumMatches else { break }

                let string = String(line)
                var searchStart = string.startIndex
                while searchStart < string.endIndex,
                      total < maximumMatches,
                      let range = string.range(
                          of: term,
                          options: options,
                          range: searchStart..<string.endIndex
                      ) {
                    let preview = string.count > 240 ? String(string.prefix(240)) + "…" : string
                    matches.append(FileMatch(
                        line: lineNumber,
                        text: preview.trimmingCharacters(in: .whitespaces)
                    ))
                    total += 1
                    searchStart = range.upperBound > range.lowerBound
                        ? range.upperBound
                        : string.index(after: range.lowerBound)
                }
            }

            if !matches.isEmpty {
                files.append(FileMatches(url: url, matches: matches))
            }
        }

        return files
    }
}
