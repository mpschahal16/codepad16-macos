import AppKit
import SwiftUI

/// Find in Files panel, modeled on Notepad++'s search across a folder.
struct FindInFilesView: View {
    let onClose: () -> Void
    let onOpen: (URL, Int) -> Void

    @StateObject private var model = FindInFilesModel()

    var body: some View {
        VStack(spacing: 0) {
            folderRow
            searchRow
            Divider()
            results
            Divider()
            footer
        }
        .frame(width: 720, height: 500)
        .onDisappear { model.cancel() }
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
            List {
                ForEach(model.results) { file in
                    Section {
                        ForEach(file.matches) { match in
                            Button {
                                onOpen(file.url, match.line)
                            } label: {
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
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(relativePath(for: file.url))
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack {
            Text(model.status)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
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
