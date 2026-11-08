import Foundation

/// The documents, selection, and view state restored on the next launch.
struct SessionState: Codable {
    struct Document: Codable {
        /// File URL as a string; nil for documents that were never saved.
        var url: String?
        /// Contents kept only when the document has unsaved changes.
        var text: String?
        var isDirty: Bool
        /// Optional so sessions saved before pinned tabs existed still load.
        var isPinned: Bool?
        var encodingID: String
        var languageID: String
        var caretPosition: Int
        var firstVisibleLine: Int
        /// Optional so sessions saved before gutter pointers existed still load.
        var pointerLines: [Int]?
    }

    var documents: [Document]
    var activeIndex: Int
}

enum SessionStore {
    private static let directoryName = "CodePad16"
    private static let fileName = "session.json"

    static var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    static func load() -> SessionState? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SessionState.self, from: data)
    }

    static func save(_ state: SessionState) {
        guard let url = fileURL else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            // The file is machine-managed; compact output is faster to write
            // and keeps large unsaved buffers from bloating it.
            try encoder.encode(state).write(to: url, options: .atomic)
        } catch {
            NSLog("CodePad16 could not save the session: %@", error.localizedDescription)
        }
    }

    static func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
