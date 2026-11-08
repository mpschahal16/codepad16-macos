import AppKit
import Carbon
import SwiftUI
import UniformTypeIdentifiers
import CodePad16Editor

/// Drag type used to reorder tabs. Restricting it to this process keeps a tab
/// drag from being treated as text by the editor or other applications.
private let tabDragType = UTType(exportedAs: "org.mpschahal16.codepad16.tab")

struct LanguageMode: Identifiable, Hashable {
    let id: String
    let name: String
    let lexer: String
    let extensions: [String]
    let keywords: [String]

    static let all: [LanguageMode] = [
        .init(id: "plain", name: "Plain Text", lexer: "", extensions: ["txt", "text"], keywords: []),
        .init(id: "c", name: "C", lexer: "cpp", extensions: ["c", "h"], keywords: ["auto break case char const continue default do double else enum extern float for goto if inline int long register restrict return short signed sizeof static struct switch typedef union unsigned void volatile while", "size_t FILE NULL true false"]),
        .init(id: "cpp", name: "C++", lexer: "cpp", extensions: ["cc", "cpp", "cxx", "hpp", "hh", "hxx"], keywords: ["alignas alignof and and_eq asm auto bitand bitor bool break case catch char class compl concept const constexpr const_cast continue co_await co_return co_yield decltype default delete do double dynamic_cast else enum explicit export extern false float for friend goto if inline int long mutable namespace new noexcept not not_eq nullptr operator or or_eq private protected public register reinterpret_cast requires return short signed sizeof static static_assert static_cast struct switch template this thread_local throw true try typedef typeid typename union unsigned using virtual void volatile wchar_t while xor", "std string vector map set unordered_map unique_ptr shared_ptr"]),
        .init(id: "csharp", name: "C#", lexer: "cpp", extensions: ["cs"], keywords: ["abstract as base bool break byte case catch char checked class const continue decimal default delegate do double else enum event explicit extern false finally fixed float for foreach goto if implicit in int interface internal is lock long namespace new null object operator out override params private protected public readonly ref return sbyte sealed short sizeof stackalloc static string struct switch this throw true try typeof uint ulong unchecked unsafe ushort using virtual void volatile while async await var get set"]),
        .init(id: "java", name: "Java", lexer: "cpp", extensions: ["java"], keywords: ["abstract assert boolean break byte case catch char class const continue default do double else enum extends final finally float for if implements import instanceof int interface long native new package private protected public return short static strictfp super switch synchronized this throw throws transient try void volatile while true false null var record sealed permits yield", "String Object System Integer List Map Set"]),
        .init(id: "javascript", name: "JavaScript", lexer: "cpp", extensions: ["js", "mjs", "cjs", "jsx"], keywords: ["async await break case catch class const continue debugger default delete do else export extends false finally for function if import in instanceof let new null return static super switch this throw true try typeof var void while with yield", "Array Boolean Date Error Function JSON Math Number Object Promise RegExp String Map Set"]),
        .init(id: "typescript", name: "TypeScript", lexer: "cpp", extensions: ["ts", "tsx"], keywords: ["abstract any as asserts async await bigint boolean break case catch class const constructor continue declare default delete do else enum export extends false finally for from function get if implements import in infer instanceof interface is keyof let module namespace never new null number object package private protected public readonly require global return set static string super switch symbol this throw true try type typeof undefined unique unknown var void while with yield", "Array Date Error Function Map Object Promise Record Set String"]),
        .init(id: "python", name: "Python", lexer: "python", extensions: ["py", "pyw", "pyi"], keywords: ["and as assert async await break class continue def del elif else except False finally for from global if import in is lambda nonlocal not or pass raise return True try while with yield None", "ArithmeticError Exception IndexError KeyError RuntimeError self super print len range"]),
        .init(id: "swift", name: "Swift", lexer: "cpp", extensions: ["swift"], keywords: ["associatedtype async await break case catch class continue defer defer else enum extension fallthrough false fileprivate for func guard if import in init inout internal let nil open operator private protocol public repeat rethrows return self Self static struct subscript super switch throw throws true try typealias var where while", "Array Bool Dictionary Double Error Float Int Optional Result Set String UInt Void"]),
        .init(id: "html", name: "HTML", lexer: "hypertext", extensions: ["html", "htm", "xhtml", "shtml"], keywords: ["a abbr address article aside audio b body br button canvas caption code div em footer form h1 h2 h3 head header html img input label li link main meta nav ol option p script section select span style table tbody td textarea th thead title tr ul video", "class id href src alt type name value role aria-label"]),
        .init(id: "css", name: "CSS", lexer: "css", extensions: ["css", "scss", "less"], keywords: ["important inherit initial unset auto none block flex grid inline inline-block absolute relative fixed sticky center cover contain"]),
        .init(id: "json", name: "JSON", lexer: "json", extensions: ["json", "jsonc", "jsonl"], keywords: []),
        .init(id: "xml", name: "XML", lexer: "xml", extensions: ["xml", "xsd", "xsl", "plist", "svg"], keywords: ["xml version encoding xmlns xmlns:xsi xsi:schemaLocation"]),
        .init(id: "sql", name: "SQL", lexer: "sql", extensions: ["sql"], keywords: ["add all alter and any as asc backup between by case check column constraint create database default delete desc distinct drop exec exists foreign from full join group index inner insert into is join key left like limit not null on or order outer primary procedure references right row select set table top truncate union unique update values view where", "bigint binary bit char date datetime decimal int integer money nchar numeric nvarchar real smallint text time timestamp tinyint uniqueidentifier varchar"])
    ]

    static func detect(url: URL?) -> LanguageMode {
        guard let ext = url?.pathExtension.lowercased(), !ext.isEmpty else { return all[0] }
        return all.first { $0.extensions.contains(ext) } ?? all[0]
    }
}

@main
struct CodePad16App: App {
    @StateObject private var store = EditorStore()
    @StateObject private var workspace = Workspace()
    @StateObject private var appearance = AppearanceSettings()
    @StateObject private var options = EditorOptions()
    @StateObject private var tools = ToolRunner()
    @StateObject private var help = HelpState()
    @StateObject private var updates = UpdateChecker()
    @StateObject private var localization = Localization.shared
    @NSApplicationDelegateAdaptor(CodePad16AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("CodePad16", id: "main") {
            CodePad16Window(appDelegate: appDelegate)
                .environmentObject(store)
                .environmentObject(workspace)
                .environmentObject(appearance)
                .environmentObject(options)
                .environmentObject(tools)
                .environmentObject(help)
                .environmentObject(updates)
                .environmentObject(localization)
                .environment(\.locale, localization.locale)
                .frame(minWidth: 760, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Picker(localization.t("Appearance"), selection: $appearance.mode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                Picker(localization.t("Language"), selection: Binding(
                    get: { localization.selection },
                    set: { localization.select($0) }
                )) {
                    Text(localization.t("System")).tag(Localization.systemID)
                    ForEach(localization.available) { language in
                        Text(language.name).tag(language.id)
                    }
                }
                Divider()
                Button(tools.isPanelVisible
                    ? localization.t("Hide Tool Runner")
                    : localization.t("Show Tool Runner")) {
                    tools.isPanelVisible.toggle()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button(localization.t("New Tab")) { store.newDocument() }
                    .keyboardShortcut("n", modifiers: .command)
                Button(localization.t("Open…")) { store.openFiles() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button(localization.t("Open Folder as Workspace…")) { workspace.chooseFolder() }
                    .keyboardShortcut("o", modifiers: [.command, .option])
                Button(localization.t("Close All Workspaces")) { workspace.close() }
                    .disabled(workspace.roots.isEmpty)
            }
            CommandGroup(replacing: .saveItem) {
                Button(localization.t("Save")) {
                    if let document = store.activeDocument { store.save(document) }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(store.activeDocument == nil)
                Button(localization.t("Save As…")) {
                    if let document = store.activeDocument { store.saveAs(document) }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.activeDocument == nil)
                Button(localization.t("Save a Copy As…")) {
                    if let document = store.activeDocument { store.saveCopyAs(document) }
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(store.activeDocument == nil)
                Button(localization.t("Rename File…")) {
                    if let document = store.activeDocument, store.rename(document) {
                        workspace.reload()
                    }
                }
                .disabled(store.activeDocument?.url == nil)
                Divider()
                Button(localization.t("Open in Other Application…")) {
                    if let document = store.activeDocument {
                        store.openInOtherApplication(document)
                    }
                }
                .disabled(store.activeDocument == nil)
                Button(localization.t("Reveal in Finder")) {
                    if let document = store.activeDocument {
                        store.revealInFinder(document)
                    }
                }
                .disabled(store.activeDocument?.url == nil)
                Divider()
                Button(localization.t("Close All Tabs")) { store.closeAll() }
                    .keyboardShortcut("w", modifiers: [.command, .option])
                    .disabled(store.documents.isEmpty)
            }
            CommandGroup(replacing: .help) {
                Button(localization.t("About CodePad16")) { help.showAbout = true }
                Button(localization.t("Check for Updates…")) { updates.checkForUpdates() }
                Divider()
                Button(localization.t("Release Notes")) { help.showReleaseNotes = true }
                Button(localization.t("License…")) { help.showLicense = true }
            }
        }
    }
}

@MainActor
final class CodePad16AppDelegate: NSObject, NSApplicationDelegate {
    var reopenWindow: (() -> Void)?
    var saveSession: (() -> Void)?
    /// The editor's window, so Finder opens can bring it to the front even if
    /// another app is active or the window is minimized.
    weak var editorWindow: NSWindow?
    /// Opens files handed over by Finder. Set once the window appears; files
    /// opened before then are held until the window can show them.
    var openFiles: (([URL]) -> Void)? {
        didSet { flushPendingOpens() }
    }
    private var pendingOpens: [URL] = []

    func applicationWillFinishLaunching(_ notification: Notification) {
        installOpenDocumentsHandler()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI installs its own document-open handler, which closes the
        // scene window and re-presents it for every external open. Install
        // ours afterwards so opening a file updates the window in place.
        installOpenDocumentsHandler()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        handleOpen(urls: urls)
    }

    /// Handles Finder's Open With, double-clicking a file, and dragging files
    /// onto the Dock icon without letting SwiftUI tear down the window.
    @objc private func handleOpenDocumentsEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        var urls: [URL] = []
        if let list = event.paramDescriptor(forKeyword: keyDirectObject) {
            for index in 1...max(list.numberOfItems, 0) {
                guard let item = list.atIndex(index) else { continue }
                if let string = item.stringValue, let url = URL(string: string) {
                    urls.append(url)
                } else if !item.data.isEmpty,
                          let url = URL(dataRepresentation: item.data, relativeTo: nil) {
                    urls.append(url)
                }
            }
        }
        handleOpen(urls: urls)
    }

    private func handleOpen(urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        guard !files.isEmpty else { return }
        guard let openFiles else {
            // Still launching: the scene creates its window and flushes these.
            pendingOpens.append(contentsOf: files)
            return
        }
        openFiles(files)
        bringWindowForward()
    }

    private func installOpenDocumentsHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentsEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
    }

    /// Brings the editor window to the front. Prefers the existing window so
    /// SwiftUI does not dismiss and re-present the scene, which looks like a
    /// relaunch, and un-minimizes it if it was in the Dock.
    private func bringWindowForward() {
        let candidates = NSApp.windows.filter { $0.canBecomeMain && !($0 is NSPanel) }
        let window = editorWindow ?? candidates.first(where: \.isVisible) ?? candidates.first

        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        guard let window else {
            reopenWindow?()
            return
        }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
    }

    private func flushPendingOpens() {
        guard let openFiles, !pendingOpens.isEmpty else { return }
        let files = pendingOpens
        pendingOpens.removeAll()
        openFiles(files)
        bringWindowForward()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            bringWindowForward()
        }
        return false
    }

    /// Keep the app running after its last window closes so opening a file from
    /// Finder reuses this process and its session instead of relaunching.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        saveSession?()
    }
}

@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    let id = UUID()
    @Published var text: String {
        didSet { isDirty = text != savedText }
    }
    @Published var isDirty = false
    @Published var languageMode: LanguageMode
    @Published var encoding: TextEncoding
    @Published var url: URL?
    /// Pinned tabs stay at the left of the tab strip and cannot be closed with
    /// the tab's close button.
    @Published var isPinned: Bool
    /// Last caret offset and scroll position, updated while the document is shown.
    var caretPosition = 0
    var firstVisibleLine = 0
    /// 1-based lines with a pointer marker in the gutter.
    var pointerLines: [Int] = []
    /// Line count as reported by the editor, so the status bar does not have to
    /// rescan the whole document whenever the view updates.
    @Published var lineCount: Int
    private var savedText: String

    init(
        text: String = "",
        url: URL? = nil,
        encoding: TextEncoding = .utf8,
        languageMode: LanguageMode? = nil,
        isPinned: Bool = false
    ) {
        self.text = text
        self.savedText = text
        self.url = url
        self.encoding = encoding
        self.languageMode = languageMode ?? LanguageMode.detect(url: url)
        self.isPinned = isPinned
        self.lineCount = Self.countLines(in: text)
    }

    var title: String { url?.lastPathComponent ?? L10n.t("Untitled") }
    var displayPath: String { url.map { ($0.path as NSString).abbreviatingWithTildeInPath } ?? L10n.t("Unsaved") }

    /// Points the document at a new path, such as after its file is renamed,
    /// without touching its saved/unsaved state.
    func updateURL(_ newURL: URL) {
        guard url != newURL else { return }
        url = newURL
        languageMode = LanguageMode.detect(url: newURL)
    }

    func markSaved(at newURL: URL? = nil) {
        if let newURL, url != newURL {
            url = newURL
            languageMode = LanguageMode.detect(url: newURL)
        }
        savedText = text
        isDirty = false
    }

    private static func countLines(in text: String) -> Int {
        var lines = 1
        for byte in text.utf8 where byte == 0x0A { lines += 1 }
        return lines
    }
}

@MainActor
final class EditorStore: ObservableObject {
    @Published private(set) var documents: [EditorDocument]
    @Published var activeDocumentID: UUID?
    /// Records the caret and scroll position of the visible document.
    var captureActiveDocument: (() -> Void)?

    init() {
        let restored = Self.restoreSession()
        if let restored, !restored.documents.isEmpty {
            documents = restored.documents
            activeDocumentID = documents[min(max(restored.activeIndex, 0), documents.count - 1)].id
        } else {
            let first = EditorDocument()
            documents = [first]
            activeDocumentID = first.id
        }
    }

    private static func restoreSession() -> (documents: [EditorDocument], activeIndex: Int)? {
        guard let state = SessionStore.load() else { return nil }
        var restored: [EditorDocument] = []

        for entry in state.documents {
            let encoding = TextEncoding.all.first { $0.id == entry.encodingID } ?? .utf8
            let language = LanguageMode.all.first { $0.id == entry.languageID }

            if let urlString = entry.url, let url = URL(string: urlString) {
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                if entry.isDirty, let text = entry.text {
                    let document = EditorDocument(
                        text: text, url: url, encoding: encoding, languageMode: language,
                        isPinned: entry.isPinned ?? false
                    )
                    document.isDirty = true
                    document.caretPosition = entry.caretPosition
                    document.firstVisibleLine = entry.firstVisibleLine
                    document.pointerLines = entry.pointerLines ?? []
                    restored.append(document)
                } else if let data = try? Data(contentsOf: url),
                          let (detectedEncoding, text) = TextEncoding.decode(data) {
                    let document = EditorDocument(
                        text: text, url: url, encoding: detectedEncoding, languageMode: language,
                        isPinned: entry.isPinned ?? false
                    )
                    document.caretPosition = entry.caretPosition
                    document.firstVisibleLine = entry.firstVisibleLine
                    document.pointerLines = entry.pointerLines ?? []
                    restored.append(document)
                }
            } else {
                let text = entry.text ?? ""
                let document = EditorDocument(
                    text: text, url: nil, encoding: encoding, languageMode: language,
                    isPinned: entry.isPinned ?? false
                )
                document.isDirty = !text.isEmpty
                document.caretPosition = entry.caretPosition
                document.firstVisibleLine = entry.firstVisibleLine
                document.pointerLines = entry.pointerLines ?? []
                restored.append(document)
            }
        }

        return (restored, state.activeIndex)
    }

    func saveSession() {
        captureActiveDocument?()
        let states = documents.map { document in
            SessionState.Document(
                url: document.url?.absoluteString,
                text: (document.isDirty || document.url == nil) ? document.text : nil,
                isDirty: document.isDirty,
                isPinned: document.isPinned,
                encodingID: document.encoding.id,
                languageID: document.languageMode.id,
                caretPosition: document.caretPosition,
                firstVisibleLine: document.firstVisibleLine,
                pointerLines: document.pointerLines
            )
        }
        let index = documents.firstIndex { $0.id == activeDocumentID } ?? 0
        SessionStore.save(SessionState(documents: states, activeIndex: index))
    }

    var activeDocument: EditorDocument? {
        documents.first { $0.id == activeDocumentID }
    }

    func newDocument() {
        captureActiveDocument?()
        let document = EditorDocument()
        documents.append(document)
        activeDocumentID = document.id
        saveSession()
    }

    func activate(_ document: EditorDocument) {
        if document.id != activeDocumentID {
            captureActiveDocument?()
        }
        activeDocumentID = document.id
        saveSession()
    }

    /// Pins or unpins a tab. Pinned tabs are kept at the left of the strip.
    func togglePin(_ document: EditorDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        document.isPinned.toggle()
        documents.remove(at: index)
        // Insert at the boundary between pinned and unpinned tabs.
        let insertion = documents.firstIndex { !$0.isPinned } ?? documents.count
        documents.insert(document, at: insertion)
        saveSession()
    }

    /// Moves a dragged tab to the end of the strip, used when it is dropped in
    /// the empty space after the last tab.
    func moveTabToEnd(id: UUID) {
        guard let from = documents.firstIndex(where: { $0.id == id }) else { return }
        let document = documents.remove(at: from)
        document.isPinned = false
        documents.append(document)
        saveSession()
    }

    /// Moves a dragged tab to where it was dropped: before or after the tab
    /// under the pointer. Dropping across the pinned boundary adopts the
    /// target tab's pinned state so the drop always lands where it was made.
    func moveTab(id: UUID, relativeTo targetID: UUID, after: Bool) {
        guard id != targetID,
              let from = documents.firstIndex(where: { $0.id == id }),
              let targetIndex = documents.firstIndex(where: { $0.id == targetID }) else { return }

        let document = documents[from]
        let targetIsPinned = documents[targetIndex].isPinned
        let shiftedTarget = targetIndex - (from < targetIndex ? 1 : 0)

        document.isPinned = targetIsPinned
        documents.remove(at: from)
        let insertion = min(max(after ? shiftedTarget + 1 : shiftedTarget, 0), documents.count)
        documents.insert(document, at: insertion)
        saveSession()
    }

    /// Opens a file without showing the open panel, activating it when it is
    /// already open. Used by Find in Files result rows.
    @discardableResult
    func openFile(at url: URL) -> EditorDocument? {
        if let existing = documents.first(where: { $0.url == url }) {
            activate(existing)
            return existing
        }
        return loadDocument(from: url, reusingBlankDocument: false)
    }

    /// Opens files handed over by the Finder, such as Open With, dragging onto
    /// the app icon, or `open -a CodePad16 file`. A single untouched Untitled
    /// document is reused so opening a file does not leave an empty tab behind.
    func openExternalFiles(_ urls: [URL]) {
        for url in urls where url.isFileURL {
            if let existing = documents.first(where: { $0.url == url }) {
                activate(existing)
                continue
            }
            loadDocument(from: url, reusingBlankDocument: true)
        }
        saveSession()
    }

    @discardableResult
    private func loadDocument(from url: URL, reusingBlankDocument: Bool) -> EditorDocument? {
        do {
            let data = try Data(contentsOf: url)
            guard let (encoding, contents) = TextEncoding.decode(data) else {
                showError(
                    L10n.f("Could not open %@", url.lastPathComponent),
                    detail: L10n.t("The file is not valid UTF-8, UTF-16, UTF-32, or ISO-8859-1 text.")
                )
                return nil
            }
            captureActiveDocument?()
            if reusingBlankDocument,
               let active = activeDocument,
               active.url == nil,
               !active.isDirty,
               active.text.isEmpty {
                active.text = contents
                active.encoding = encoding
                active.markSaved(at: url)
                activeDocumentID = active.id
                saveSession()
                return active
            }
            let document = EditorDocument(text: contents, url: url, encoding: encoding)
            documents.append(document)
            activeDocumentID = document.id
            saveSession()
            return document
        } catch {
            showError(L10n.f("Could not open %@", url.lastPathComponent), detail: error.localizedDescription)
            return nil
        }
    }

    func openFiles() {
        captureActiveDocument?()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = L10n.t("Open")
        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            if let existing = documents.first(where: { $0.url == url }) {
                activeDocumentID = existing.id
                continue
            }
            do {
                let data = try Data(contentsOf: url)
                guard let (encoding, contents) = TextEncoding.decode(data) else {
                    showError(
                        L10n.f("Could not open %@", url.lastPathComponent),
                        detail: L10n.t("The file is not valid UTF-8, UTF-16, UTF-32, or ISO-8859-1 text.")
                    )
                    continue
                }
                let document = EditorDocument(text: contents, url: url, encoding: encoding)
                documents.append(document)
                activeDocumentID = document.id
            } catch {
                showError(L10n.f("Could not open %@", url.lastPathComponent), detail: error.localizedDescription)
            }
        }
        saveSession()
    }

    @discardableResult
    func save(_ document: EditorDocument) -> Bool {
        guard let url = document.url else { return saveAs(document) }
        return write(document, to: url)
    }

    @discardableResult
    func saveAs(_ document: EditorDocument) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.item]
        panel.title = L10n.t("Save As…")
        panel.prompt = L10n.t("Save")
        panel.nameFieldStringValue = document.url == nil
            ? L10n.t("Untitled") + ".txt"
            : document.title
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return write(document, to: url)
    }

    /// Writes the current contents to a new file without moving the open
    /// document or changing whether it has unsaved changes.
    @discardableResult
    func saveCopyAs(_ document: EditorDocument) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.item]
        panel.title = L10n.t("Save a Copy")
        panel.message = L10n.t("The open tab keeps its current file.")
        panel.prompt = L10n.t("Save")
        panel.nameFieldStringValue = document.url == nil
            ? L10n.t("Untitled") + ".txt"
            : document.title
        guard panel.runModal() == .OK, let url = panel.url else { return false }

        guard let data = document.encoding.encode(document.text) else {
            showError(
                L10n.f("Could not save %@", url.lastPathComponent),
                detail: L10n.f(
                    "Some characters cannot be represented in %@. Choose UTF-8 in the status bar and try again.",
                    document.encoding.name
                )
            )
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            showError(L10n.f("Could not save %@", url.lastPathComponent), detail: error.localizedDescription)
            return false
        }
    }

    /// Asks for a new name and renames the file on disk, keeping any open
    /// document pointed at the new path.
    @discardableResult
    func renameFile(at url: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.f("Rename “%@”", url.lastPathComponent)
        alert.informativeText = L10n.t("Enter a new name for this file.")
        alert.addButton(withTitle: L10n.t("Rename"))
        alert.addButton(withTitle: L10n.t("Cancel"))

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.stringValue = url.lastPathComponent
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, !newName.contains("/"), !newName.contains(":") else {
            showError(
                L10n.f("Could not rename %@", url.lastPathComponent),
                detail: L10n.t("Enter a file name without slashes or colons.")
            )
            return false
        }
        guard newName != url.lastPathComponent else { return false }

        let target = url.deletingLastPathComponent().appendingPathComponent(newName)
        // On a case-insensitive file system, "abc" and "ABC" are the same file;
        // renaming only the case needs a detour through a temporary name.
        let caseOnlyRename = target.path.lowercased() == url.path.lowercased()

        if !caseOnlyRename, FileManager.default.fileExists(atPath: target.path) {
            let confirm = NSAlert()
            confirm.alertStyle = .warning
            confirm.messageText = L10n.f("“%@” already exists.", newName)
            confirm.informativeText = L10n.t("Replacing it cannot be undone.")
            confirm.addButton(withTitle: L10n.t("Replace"))
            confirm.addButton(withTitle: L10n.t("Cancel"))
            guard confirm.runModal() == .alertFirstButtonReturn else { return false }
        }

        do {
            try Self.moveFile(at: url, to: target)
        } catch {
            showError(L10n.f("Could not rename %@", url.lastPathComponent), detail: error.localizedDescription)
            return false
        }

        for document in documents where document.url == url {
            document.updateURL(target)
        }
        saveSession()
        return true
    }

    /// Moves a file to a new path in the same folder, replacing an existing
    /// file and routing case-only renames through a temporary name so they
    /// work on case-insensitive volumes.
    static func moveFile(at url: URL, to target: URL) throws {
        let manager = FileManager.default
        let caseOnlyRename = target.path.lowercased() == url.path.lowercased()

        if !caseOnlyRename, manager.fileExists(atPath: target.path) {
            try manager.removeItem(at: target)
        }

        if caseOnlyRename {
            let temporary = url.deletingLastPathComponent()
                .appendingPathComponent(".codepad16-rename-\(UUID().uuidString)")
            try manager.moveItem(at: url, to: temporary)
            try manager.moveItem(at: temporary, to: target)
        } else {
            try manager.moveItem(at: url, to: target)
        }
    }

    @discardableResult
    func rename(_ document: EditorDocument) -> Bool {
        guard let url = document.url else { return false }
        return renameFile(at: url)
    }

    /// Saves a copy of a file that may not be open, using the open buffer when
    /// there is one so unsaved edits are included.
    @discardableResult
    func saveCopyOfFile(at url: URL) -> Bool {
        if let document = documents.first(where: { $0.url == url }) {
            return saveCopyAs(document)
        }
        guard let data = try? Data(contentsOf: url) else {
            showError(L10n.f("Could not copy %@", url.lastPathComponent), detail: L10n.t("The file could not be read."))
            return false
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.item]
        panel.title = L10n.t("Save a Copy")
        panel.message = L10n.t("The original file is left unchanged.")
        panel.prompt = L10n.t("Save")
        panel.nameFieldStringValue = url.lastPathComponent
        guard panel.runModal() == .OK, let target = panel.url else { return false }
        do {
            try data.write(to: target, options: .atomic)
            return true
        } catch {
            showError(L10n.f("Could not save %@", target.lastPathComponent), detail: error.localizedDescription)
            return false
        }
    }

    func isOpen(_ url: URL) -> Bool {
        document(at: url) != nil
    }

    func document(at url: URL) -> EditorDocument? {
        documents.first { $0.url == url }
    }

    func closeFile(at url: URL) {
        guard let document = documents.first(where: { $0.url == url }) else { return }
        close(document)
    }

    /// Saves pending changes, then lets the user pick an application to open
    /// the file with. Useful for previewing markup or handing a file off to
    /// another editor.
    func openInOtherApplication(_ document: EditorDocument) {
        if document.url == nil || document.isDirty {
            if document.isDirty {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = L10n.f("Save changes before opening %@ in another application?", document.title)
                alert.informativeText = L10n.t("The other application will open the saved version of the file.")
                alert.addButton(withTitle: L10n.t("Save and Open"))
                alert.addButton(withTitle: L10n.t("Cancel"))
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }
            guard save(document) else { return }
        }
        guard let url = document.url else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first
        panel.message = L10n.f("Choose an application to open %@ with.", url.lastPathComponent)
        panel.prompt = L10n.t("Open")
        guard panel.runModal() == .OK, let applicationURL = panel.url else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [url],
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { [weak self] _, error in
            guard let error else { return }
            Task { @MainActor in
                self?.showError(
                    L10n.f("Could not open %@", url.lastPathComponent),
                    detail: error.localizedDescription
                )
            }
        }
    }

    /// Shows the document's saved file in Finder.
    func revealInFinder(_ document: EditorDocument) {
        guard let url = document.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func close(_ document: EditorDocument) {
        if document.isDirty {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = L10n.f("Save changes to %@?", document.title)
            alert.informativeText = L10n.t("Your edits will be lost if you close this tab without saving.")
            alert.addButton(withTitle: L10n.t("Save"))
            alert.addButton(withTitle: L10n.t("Cancel"))
            alert.addButton(withTitle: L10n.t("Discard Changes"))
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                guard save(document) else { return }
            case .alertThirdButtonReturn:
                break
            default:
                return
            }
        }

        documents.removeAll { $0.id == document.id }
        if documents.isEmpty { newDocument(); return }
        if activeDocumentID == document.id { activeDocumentID = documents.last?.id }
        saveSession()
    }

    /// Closes every tab, asking once whether to save unsaved edits.
    func closeAll() {
        let closable = documents.filter { !$0.isPinned }
        guard !closable.isEmpty else { return }
        let dirty = closable.filter(\.isDirty)
        if !dirty.isEmpty {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = dirty.count == 1
                ? L10n.f("Save changes to %@?", dirty[0].title)
                : L10n.f("Save changes to %lld tabs?", dirty.count)
            alert.informativeText = L10n.t("Your edits will be lost if you close these tabs without saving.")
            alert.addButton(withTitle: L10n.t("Save All"))
            alert.addButton(withTitle: L10n.t("Cancel"))
            alert.addButton(withTitle: L10n.t("Discard Changes"))
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                for document in dirty {
                    guard save(document) else { return }
                }
            case .alertThirdButtonReturn:
                break
            default:
                return
            }
        }

        let closedActive = activeDocument?.isPinned == false
        documents.removeAll { !$0.isPinned }
        if documents.isEmpty {
            newDocument()
            return
        }
        if closedActive { activeDocumentID = documents.last?.id }
        saveSession()
    }

    private func write(_ document: EditorDocument, to url: URL) -> Bool {
        guard let data = document.encoding.encode(document.text) else {
            showError(
                L10n.f("Could not save %@", url.lastPathComponent),
                detail: L10n.f(
                    "Some characters cannot be represented in %@. Choose UTF-8 in the status bar and save again.",
                    document.encoding.name
                )
            )
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            document.markSaved(at: url)
            saveSession()
            return true
        } catch {
            showError(L10n.f("Could not save %@", url.lastPathComponent), detail: error.localizedDescription)
            return false
        }
    }

    private func showError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = detail
        alert.runModal()
    }
}

struct CodePad16Window: View {
    let appDelegate: CodePad16AppDelegate
    @EnvironmentObject private var store: EditorStore
    @EnvironmentObject private var workspace: Workspace
    @EnvironmentObject private var appearance: AppearanceSettings
    @EnvironmentObject private var options: EditorOptions
    @EnvironmentObject private var tools: ToolRunner
    @EnvironmentObject private var help: HelpState
    @EnvironmentObject private var updates: UpdateChecker
    @EnvironmentObject private var localization: Localization
    @Environment(\.openWindow) private var openWindow
    @StateObject private var windowState = WindowState()
    @StateObject private var editorController = EditorController()

    var body: some View {
        VStack(spacing: 0) {
            header
            tabStrip
            if windowState.showFind {
                findBar
            }
            HSplitView {
                if !workspace.roots.isEmpty {
                    WorkspaceSidebar(
                        workspace: workspace,
                        onOpenFile: { url in store.openFile(at: url) },
                        onSave: { url in
                            if let document = store.document(at: url) { store.save(document) }
                        },
                        onSaveAs: { url in
                            if let document = store.document(at: url),
                               store.saveAs(document) {
                                workspace.reload()
                            }
                        },
                        onSaveCopy: { url in store.saveCopyOfFile(at: url) },
                        onRenameFile: { url in
                            if store.renameFile(at: url) { workspace.reload() }
                        },
                        onCloseFile: { url in store.closeFile(at: url) },
                        isFileOpen: { url in store.isOpen(url) }
                    )
                }
                editorContent
                if tools.isPanelVisible {
                    ToolRunnerPanel(
                        controller: editorController,
                        document: store.activeDocument,
                        output: tools.output
                    )
                        .frame(minWidth: 300, idealWidth: 380, maxWidth: 620)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .background(WindowAccessor { appDelegate.editorWindow = $0 })
        .modifier(WindowTitleModifier(document: store.activeDocument))
        .sheet(isPresented: $help.showAbout) {
            AboutView { help.showAbout = false }
        }
        .sheet(isPresented: $help.showLicense) {
            LicenseView { help.showLicense = false }
        }
        .sheet(isPresented: $help.showReleaseNotes) {
            ReleaseNotesView { help.showReleaseNotes = false }
        }
        .sheet(isPresented: $updates.isPresented) {
            UpdateView(onClose: { updates.isPresented = false }, checker: updates)
        }
        .onAppear {
            appearance.apply()
            appDelegate.reopenWindow = { openWindow(id: "main") }
            appDelegate.saveSession = { store.saveSession() }
            appDelegate.openFiles = { store.openExternalFiles($0) }
            store.captureActiveDocument = { [weak store] in
                guard let store, let document = store.activeDocument else { return }
                editorController.captureState(into: document)
            }
        }
    }

    @ViewBuilder
    private var editorContent: some View {
        if let document = store.activeDocument {
            VStack(spacing: 0) {
                EditorPane(document: document, controller: editorController, wordWrap: options.wordWrap)
                StatusBar(document: document, controller: editorController)
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 10) {
                Image(systemName: "doc.text").font(.system(size: 28)).foregroundStyle(.secondary)
                Text("No document open").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            CatLogoMark(size: 32)
            Text("CodePad16")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Menu {
                Button { store.newDocument() } label: { Label("New Tab", systemImage: "doc.badge.plus") }
                    .keyboardShortcut("n", modifiers: .command)
                Button { store.openFiles() } label: { Label("Open…", systemImage: "folder") }
                    .keyboardShortcut("o", modifiers: .command)
                Button { workspace.chooseFolder() } label: {
                    Label("Open Folder as Workspace…", systemImage: "folder.badge.plus")
                }
                .keyboardShortcut("o", modifiers: [.command, .option])
                Button { workspace.close() } label: {
                    Label("Close All Workspaces", systemImage: "xmark.circle")
                }
                .disabled(workspace.roots.isEmpty)
                Divider()
                Button {
                    if let document = store.activeDocument { store.save(document) }
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(store.activeDocument == nil)
                Button {
                    if let document = store.activeDocument { store.saveAs(document) }
                } label: {
                    Label("Save As…", systemImage: "square.and.arrow.down.on.square")
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.activeDocument == nil)
                Button {
                    if let document = store.activeDocument { store.saveCopyAs(document) }
                } label: {
                    Label("Save a Copy As…", systemImage: "doc.on.doc")
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(store.activeDocument == nil)
                Button {
                    if let document = store.activeDocument, store.rename(document) {
                        workspace.reload()
                    }
                } label: {
                    Label("Rename File…", systemImage: "pencil")
                }
                .disabled(store.activeDocument?.url == nil)
                Divider()
                Button {
                    if let document = store.activeDocument { store.openInOtherApplication(document) }
                } label: {
                    Label("Open in Other Application…", systemImage: "arrow.up.forward.app")
                }
                .disabled(store.activeDocument == nil)
                Button {
                    if let document = store.activeDocument { store.revealInFinder(document) }
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }
                .disabled(store.activeDocument?.url == nil)
                Divider()
                Button {
                    store.closeAll()
                } label: {
                    Label("Close All Tabs", systemImage: "xmark.circle")
                }
                .keyboardShortcut("w", modifiers: [.command, .option])
                .disabled(store.documents.isEmpty)
            } label: {
                Label("File", systemImage: "folder")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("File actions")
            Menu {
                Button { toggleFindBar() } label: { Label("Find…", systemImage: "magnifyingglass") }
                    .keyboardShortcut("f", modifiers: .command)
                Button { openReplaceBar() } label: { Label("Replace…", systemImage: "arrow.left.arrow.right") }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Button { openFindInFiles() } label: {
                    Label("Find in Files…", systemImage: "doc.text.magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                Divider()
                Button { findInDocument(backwards: false) } label: { Text("Find Next") }
                    .keyboardShortcut("g", modifiers: .command)
                Button { findInDocument(backwards: true) } label: { Text("Find Previous") }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Divider()
                Button { promptGoToLine() } label: { Label("Go to Line…", systemImage: "number") }
                    .keyboardShortcut("l", modifiers: .command)
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Search actions")
            Menu {
                Toggle("Word Wrap", isOn: $options.wordWrap)
            } label: {
                Label("Editor", systemImage: "textformat")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Editor options")
            Button { tools.isPanelVisible.toggle() } label: { Label("Tools", systemImage: "sparkles") }
                .help(tools.isPanelVisible
                    ? LocalizedStringKey("Hide tool runner")
                    : LocalizedStringKey("Show tool runner"))
            Menu {
                Button("About CodePad16") { help.showAbout = true }
                Button("Check for Updates…") { updates.checkForUpdates() }
                Divider()
                Button("Release Notes") { help.showReleaseNotes = true }
                Button("License…") { help.showLicense = true }
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Help")
            Divider().frame(height: 18)
            Menu {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appearance.mode = mode
                    } label: {
                        if appearance.mode == mode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }
            } label: {
                Label(appearance.mode.title, systemImage: appearance.mode.symbolName)
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Appearance: \(appearance.mode.title)")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func findInDocument(backwards: Bool) {
        guard !windowState.findQuery.isEmpty else {
            // Without a query, show the find bar so there is something to search for.
            windowState.showFind = true
            return
        }
        windowState.recordSearch(windowState.findQuery)
        if backwards {
            editorController.findPrevious(windowState.findQuery)
        } else {
            editorController.findNext(windowState.findQuery)
        }
    }

    private var findStatusText: String {
        guard !windowState.findQuery.isEmpty else { return "" }
        let info = editorController.matchInfo(windowState.findQuery)
        guard info.total > 0 else { return L10n.t("No matches") }
        // A selection past the last match wraps to the first one.
        let index = info.index > 0 ? info.index : 1
        return L10n.f("%lld of %lld", index, info.total)
    }

    private func openReplaceBar() {
        windowState.showFind = true
        windowState.showReplace = true
        windowState.replaceStatus = ""
    }

    private func toggleFindBar() {
        if windowState.showFind {
            closeFindBar()
        } else {
            windowState.showFind = true
        }
    }

    private func closeFindBar() {
        windowState.showFind = false
        windowState.showReplace = false
        windowState.findQuery = ""
        windowState.replaceQuery = ""
        windowState.replaceStatus = ""
    }

    private func promptGoToLine() {
        let alert = NSAlert()
        alert.messageText = L10n.t("Go to Line")
        alert.informativeText = L10n.f("Enter a line number between 1 and %lld.", editorController.lineCount)
        alert.addButton(withTitle: L10n.t("Go"))
        alert.addButton(withTitle: L10n.t("Cancel"))
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.placeholderString = L10n.t("Line number")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let line = Int(field.stringValue), line > 0 {
            editorController.goToLine(line)
        }
    }

    private func openFindInFiles() {
        if let panel = windowState.findInFilesPanel {
            panel.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = localization.t("Find in Files")
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: FindInFilesView(
            initialFolder: workspace.roots.first,
            onClose: { [weak panel] in panel?.close() },
            onOpen: { url, line in openSearchResult(url, line: line) }
        )
        .environmentObject(localization)
        .environment(\.locale, localization.locale))
        panel.center()
        windowState.findInFilesPanel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func openSearchResult(_ url: URL, line: Int) {
        guard let document = store.openFile(at: url) else { return }
        // Restore the caret when the editor view is rebuilt, and jump once the
        // active document has switched for an already-open tab.
        document.caretPosition = Self.byteOffset(ofLine: line, in: document.text)
        DispatchQueue.main.async {
            editorController.goToLine(line)
        }
    }

    private static func byteOffset(ofLine line: Int, in text: String) -> Int {
        guard line > 1 else { return 0 }
        var currentLine = 1
        var offset = 0
        for byte in text.utf8 {
            if currentLine >= line { break }
            offset += 1
            if byte == 0x0A { currentLine += 1 }
        }
        return offset
    }

    private func replaceCurrentMatch() {
        guard !windowState.findQuery.isEmpty else { return }
        windowState.recordSearch(windowState.findQuery)
        windowState.recordReplacement(windowState.replaceQuery)
        let replaced = editorController.replaceCurrent(
            windowState.findQuery,
            with: windowState.replaceQuery
        )
        windowState.replaceStatus = replaced ? L10n.t("Replaced 1 match") : ""
    }

    private func replaceAllMatches() {
        guard !windowState.findQuery.isEmpty else { return }
        windowState.recordSearch(windowState.findQuery)
        windowState.recordReplacement(windowState.replaceQuery)
        let count = editorController.replaceAll(
            windowState.findQuery,
            with: windowState.replaceQuery
        )
        switch count {
        case 0:
            windowState.replaceStatus = L10n.t("No matches")
        case 1:
            windowState.replaceStatus = L10n.t("Replaced 1 match")
        default:
            windowState.replaceStatus = L10n.f("Replaced %lld matches", count)
        }
    }

    private var findBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 9) {
                HistoryComboBox(
                    text: $windowState.findQuery,
                    items: windowState.findHistory,
                    placeholder: localization.t("Find in document"),
                    onSubmit: { findInDocument(backwards: false) }
                )
                .frame(minWidth: 140, maxWidth: .infinity)
                Button { findInDocument(backwards: true) } label: {
                    Image(systemName: "chevron.up")
                }
                .help("Previous match")
                Button { findInDocument(backwards: false) } label: {
                    Image(systemName: "chevron.down")
                }
                .help("Next match")
                Button {
                    windowState.showReplace.toggle()
                    windowState.replaceStatus = ""
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .help(windowState.showReplace
                    ? LocalizedStringKey("Hide replace")
                    : LocalizedStringKey("Show replace"))
                Toggle("Match case", isOn: $editorController.matchCase)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .help("Match case")
                Text(findStatusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button {
                    closeFindBar()
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Close Find")
            }
            if windowState.showReplace {
                HStack(spacing: 9) {
                    HistoryComboBox(
                        text: $windowState.replaceQuery,
                        items: windowState.replaceHistory,
                        placeholder: localization.t("Replace with"),
                        onSubmit: { replaceCurrentMatch() }
                    )
                    .frame(minWidth: 140, maxWidth: .infinity)
                    Button("Replace") { replaceCurrentMatch() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Replace All") { replaceAllMatches() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Text(windowState.replaceStatus)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private func recordTabWidth(_ id: UUID, _ width: CGFloat) {
        guard windowState.tabWidths[id] != width else { return }
        windowState.tabWidths[id] = width
    }

    private var tabStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(store.documents) { document in
                        DocumentTab(document: document, isSelected: document.id == store.activeDocumentID) {
                            store.activate(document)
                        } onClose: {
                            store.close(document)
                        } onTogglePin: {
                            store.togglePin(document)
                        }
                        .id(document.id)
                        .onDrag {
                            let provider = NSItemProvider()
                            provider.registerDataRepresentation(
                                forTypeIdentifier: tabDragType.identifier,
                                visibility: .ownProcess
                            ) { completion in
                                completion(document.id.uuidString.data(using: .utf8), nil)
                                return nil
                            }
                            return provider
                        }
                        .onDrop(
                            of: [tabDragType],
                            delegate: TabDropDelegate(
                                target: document,
                                width: windowState.tabWidths[document.id] ?? 0,
                                store: store
                            )
                        )
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear {
                                        recordTabWidth(document.id, proxy.size.width)
                                    }
                                    .onChange(of: proxy.size.width) { width in
                                        recordTabWidth(document.id, width)
                                    }
                            }
                        )
                        .contextMenu {
                            Button {
                                store.togglePin(document)
                            } label: {
                                Label(
                                    localization.t(document.isPinned ? "Unpin Tab" : "Pin Tab"),
                                    systemImage: document.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            Divider()
                            Button("Save") { store.save(document) }
                            Button("Save As…") { store.saveAs(document) }
                            Button("Save a Copy As…") { store.saveCopyAs(document) }
                            Divider()
                            Button("Rename File…") {
                                if store.rename(document) { workspace.reload() }
                            }
                            .disabled(document.url == nil)
                            Button("Open in Other Application…") {
                                store.openInOtherApplication(document)
                            }
                            Button("Reveal in Finder") {
                                store.revealInFinder(document)
                            }
                            .disabled(document.url == nil)
                            Divider()
                            Button("Close Tab") { store.close(document) }
                            Button("Close All Tabs") { store.closeAll() }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .onDrop(
                of: [tabDragType],
                delegate: TabStripDropDelegate(store: store)
            )
            .onAppear {
                guard let id = store.activeDocumentID else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onChange(of: store.activeDocumentID) { id in
                guard let id else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
        .frame(height: 38)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

}

/// Resolves the NSWindow hosting the editor so the app delegate can bring it
/// forward when a file is opened from the Finder.
private struct WindowAccessor: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResolve: onResolve)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.update(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(nsView.window)
    }

    final class Coordinator {
        private let onResolve: (NSWindow?) -> Void
        private weak var window: NSWindow?

        init(onResolve: @escaping (NSWindow?) -> Void) {
            self.onResolve = onResolve
        }

        func update(_ newWindow: NSWindow?) {
            guard newWindow !== window else { return }
            window = newWindow
            onResolve(newWindow)
        }
    }
}

/// The window title follows the active document and updates when it is renamed.
private struct WindowTitleModifier: ViewModifier {
    let document: EditorDocument?

    func body(content: Content) -> some View {
        if let document {
            content.modifier(LiveTitleModifier(document: document))
        } else {
            content.navigationTitle("CodePad16")
        }
    }
}

private struct LiveTitleModifier: ViewModifier {
    @ObservedObject var document: EditorDocument
    @EnvironmentObject private var localization: Localization

    func body(content: Content) -> some View {
        content.navigationTitle("\(document.title) - CodePad16")
    }
}

/// Observes only the document, so typing does not rebuild the whole window.
struct StatusBar: View {
    @ObservedObject var document: EditorDocument
    let controller: EditorController
    @EnvironmentObject private var localization: Localization

    var body: some View {
        HStack(spacing: 14) {
            Menu {
                ForEach(LanguageMode.all) { mode in
                    Button {
                        document.languageMode = mode
                    } label: {
                        if document.languageMode.id == mode.id {
                            Label(localization.t(mode.name), systemImage: "checkmark")
                        } else {
                            Text(localization.t(mode.name))
                        }
                    }
                }
            } label: {
                Label(localization.t(document.languageMode.name), systemImage: "chevron.up.chevron.down")
            }
            .menuStyle(.borderlessButton)
            Menu {
                ForEach(TextEncoding.all) { encoding in
                    Button {
                        document.encoding = encoding
                    } label: {
                        if document.encoding.id == encoding.id {
                            Label(encoding.name, systemImage: "checkmark")
                        } else {
                            Text(encoding.name)
                        }
                    }
                }
            } label: {
                Text(document.encoding.name)
            }
            .menuStyle(.borderlessButton)
            .help("File encoding")
            Text("\(document.lineCount) lines")
            Spacer()
            if document.isDirty { Text("Modified").foregroundStyle(.orange) }
            Text(document.displayPath)
                .lineLimit(1)
                .truncationMode(.middle)
                .layoutPriority(1)
                .help(document.url?.path ?? localization.t("This document has not been saved yet"))
            CursorReadout(controller: controller)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .top) { Divider() }
    }
}

/// Isolated so caret movement only invalidates this label.
struct CursorReadout: View {
    @ObservedObject var controller: EditorController

    var body: some View {
        Text("Ln: \(controller.cursorLine), Col: \(controller.cursorColumn)")
            .monospacedDigit()
            .help("Current line and column")
    }
}

struct DocumentTab: View {
    @ObservedObject var document: EditorDocument
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onTogglePin: () -> Void
    @EnvironmentObject private var localization: Localization

    var body: some View {
        HStack(spacing: 7) {
            pinButton
            if document.isDirty {
                Circle().fill(Color.accentColor).frame(width: 6, height: 6)
            }
            Button(action: onSelect) {
                Text(document.title).lineLimit(1).frame(maxWidth: 150)
            }
            .buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                    .frame(width: 17, height: 17)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close tab")
        }
        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
        .padding(.horizontal, 10)
        .frame(height: 37)
        .background(isSelected ? Color(nsColor: .textBackgroundColor) : Color.clear)
        .overlay(alignment: .bottom) {
            if isSelected { Rectangle().fill(Color.accentColor).frame(height: 2) }
        }
        .help(document.url?.path ?? localization.t("This document has not been saved yet"))
    }

    /// Pin button beside the file name, for pinning and unpinning the tab.
    private var pinButton: some View {
        Button(action: onTogglePin) {
            Image(systemName: document.isPinned ? "pin.fill" : "pin")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(document.isPinned ? Color.accentColor : Color.secondary)
                .frame(width: 14, height: 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(localization.t(document.isPinned ? "Unpin tab" : "Pin tab"))
    }
}

/// Handles a tab dropped onto another tab. The drop lands before or after the
/// tab depending on which half of it the pointer is over.
private struct TabDropDelegate: DropDelegate {
    let target: EditorDocument
    let width: CGFloat
    let store: EditorStore

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [tabDragType])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [tabDragType]).first else { return false }
        let after = width > 0 && info.location.x > width / 2
        provider.loadDataRepresentation(forTypeIdentifier: tabDragType.identifier) { data, _ in
            guard let data,
                  let string = String(data: data, encoding: .utf8),
                  let draggedID = UUID(uuidString: string) else { return }
            Task { @MainActor in
                store.moveTab(id: draggedID, relativeTo: target.id, after: after)
            }
        }
        return true
    }
}

/// Handles a tab dropped in the empty space after the last tab, moving it to
/// the end of the strip.
private struct TabStripDropDelegate: DropDelegate {
    let store: EditorStore

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [tabDragType])
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [tabDragType]).first else { return false }
        provider.loadDataRepresentation(forTypeIdentifier: tabDragType.identifier) { data, _ in
            guard let data,
                  let string = String(data: data, encoding: .utf8),
                  let draggedID = UUID(uuidString: string) else { return }
            Task { @MainActor in
                store.moveTabToEnd(id: draggedID)
            }
        }
        return true
    }
}

struct EditorPane: View {
    @ObservedObject var document: EditorDocument
    let controller: EditorController
    let wordWrap: Bool

    var body: some View {
        NativeTextEditor(
            text: $document.text,
            document: document,
            mode: document.languageMode,
            controller: controller,
            wordWrap: wordWrap
        )
        .accessibilityLabel("Text editor")
    }
}

@MainActor
final class WindowState: ObservableObject {
    @Published var showFind = false
    @Published var showReplace = false
    @Published var findQuery = ""
    @Published var replaceQuery = ""
    @Published var replaceStatus = ""
    var findInFilesPanel: NSPanel?
    /// Widths of the tabs in the strip, used to decide which half of a tab a
    /// drag was dropped on.
    @Published var tabWidths: [UUID: CGFloat] = [:]
    @Published private(set) var findHistory: [String]
    @Published private(set) var replaceHistory: [String]

    private static let findHistoryKey = "CodePad16.findHistory"
    private static let replaceHistoryKey = "CodePad16.replaceHistory"
    private static let historyLimit = 10

    init() {
        let defaults = UserDefaults.standard
        findHistory = defaults.stringArray(forKey: Self.findHistoryKey) ?? []
        replaceHistory = defaults.stringArray(forKey: Self.replaceHistoryKey) ?? []
    }

    func recordSearch(_ term: String) {
        findHistory = Self.record(term, in: findHistory)
        UserDefaults.standard.set(findHistory, forKey: Self.findHistoryKey)
    }

    func recordReplacement(_ term: String) {
        replaceHistory = Self.record(term, in: replaceHistory)
        UserDefaults.standard.set(replaceHistory, forKey: Self.replaceHistoryKey)
    }

    func clearSearchHistory() {
        findHistory = []
        UserDefaults.standard.removeObject(forKey: Self.findHistoryKey)
    }

    func clearReplaceHistory() {
        replaceHistory = []
        UserDefaults.standard.removeObject(forKey: Self.replaceHistoryKey)
    }

    private static func record(_ term: String, in history: [String]) -> [String] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return history }
        var updated = history.filter { $0 != trimmed }
        updated.insert(trimmed, at: 0)
        if updated.count > historyLimit {
            updated.removeLast(updated.count - historyLimit)
        }
        return updated
    }
}

/// Shared help state so the in-window Help menu and the macOS Help menu
/// can present the same panels.
@MainActor
final class HelpState: ObservableObject {
    @Published var showAbout = false
    @Published var showLicense = false
    @Published var showReleaseNotes = false
}

@MainActor
final class EditorController: ObservableObject {
    weak var scintillaView: CodePad16ScintillaView?
    @Published private(set) var cursorLine = 1
    @Published private(set) var cursorColumn = 1
    @Published var matchCase = false

    private func prepare(_ editor: CodePad16ScintillaView) -> CodePad16ScintillaView {
        editor.matchCase = matchCase
        return editor
    }

    func updateCursorPosition(line: Int, column: Int) {
        let newLine = max(1, line)
        let newColumn = max(1, column)
        // Only publish when the position actually changes, so holding an arrow
        // key does not invalidate views that show the same value.
        if newLine != cursorLine { cursorLine = newLine }
        if newColumn != cursorColumn { cursorColumn = newColumn }
    }

    func captureState(into document: EditorDocument) {
        guard let editor = scintillaView else { return }
        document.caretPosition = editor.caretPosition
        document.firstVisibleLine = editor.firstVisibleLine
        document.pointerLines = editor.pointerLines.map { $0.intValue }
    }

    func findNext(_ query: String) {
        guard let editor = scintillaView else { return }
        prepare(editor).find(query, backwards: false)
    }
    func findPrevious(_ query: String) {
        guard let editor = scintillaView else { return }
        prepare(editor).find(query, backwards: true)
    }
    func replaceCurrent(_ query: String, with replacement: String) -> Bool {
        guard let editor = scintillaView else { return false }
        return prepare(editor).replace(query, with: replacement)
    }
    func replaceAll(_ query: String, with replacement: String) -> Int {
        guard let editor = scintillaView else { return 0 }
        return prepare(editor).replaceAll(query, with: replacement)
    }
    func goToLine(_ line: Int) {
        guard let editor = scintillaView else { return }
        prepare(editor).go(toLine: line)
    }

    var lineCount: Int { scintillaView?.lineCount ?? 1 }

    var selectedText: String { scintillaView?.selectedText ?? "" }

    func matchInfo(_ query: String) -> (index: Int, total: Int) {
        guard let editor = scintillaView else { return (0, 0) }
        let info = prepare(editor).matchInfo(query)
        return (info.location, info.length)
    }
}

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    let document: EditorDocument
    let mode: LanguageMode
    /// Not observed: the coordinator pushes cursor updates, and observing the
    /// controller here would re-run this view on every caret move.
    let controller: EditorController
    let wordWrap: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> CodePad16ScintillaView {
        let editor = CodePad16ScintillaView(frame: .zero)
        editor.lexerName = mode.lexer
        editor.keywordSets = mode.keywords
        editor.wordWrap = wordWrap
        editor.text = text
        editor.pointerLines = document.pointerLines.map { NSNumber(value: $0) }
        context.coordinator.loadedDocumentID = document.id
        context.coordinator.lastText = text
        context.coordinator.restoreViewState(
            caretPosition: document.caretPosition,
            firstVisibleLine: document.firstVisibleLine,
            in: editor
        )
        editor.onChange = { [weak coordinator = context.coordinator] editedText, line, column, modified, lineCount in
            coordinator?.editorDidChange(
                text: editedText,
                line: line,
                column: column,
                modified: modified,
                lineCount: lineCount
            )
        }
        editor.onPointerChange = { [weak coordinator = context.coordinator] lines in
            coordinator?.pointersDidChange(lines)
        }
        controller.scintillaView = editor
        return editor
    }

    func updateNSView(_ editor: CodePad16ScintillaView, context: Context) {
        let coordinator = context.coordinator
        // The view is reused when the active tab changes, so the callback must follow
        // the current binding instead of the document that created the view.
        coordinator.parent = self
        controller.scintillaView = editor

        coordinator.isUpdatingFromView = true
        defer { coordinator.isUpdatingFromView = false }

        if coordinator.loadedDocumentID != document.id {
            editor.text = text
            editor.pointerLines = document.pointerLines.map { NSNumber(value: $0) }
            coordinator.lastText = text
            coordinator.loadedDocumentID = document.id
            coordinator.resetStatusCache()
            coordinator.restoreViewState(
                caretPosition: document.caretPosition,
                firstVisibleLine: document.firstVisibleLine,
                in: editor
            )
        } else if coordinator.lastText != text {
            // The text changed somewhere other than the editor, such as a
            // restored session or an encoding change.
            editor.text = text
            editor.pointerLines = document.pointerLines.map { NSNumber(value: $0) }
            coordinator.lastText = text
        }

        if editor.lexerName != mode.lexer { editor.lexerName = mode.lexer }
        if editor.keywordSets != mode.keywords { editor.keywordSets = mode.keywords }
        if editor.wordWrap != wordWrap { editor.wordWrap = wordWrap }
    }

    final class Coordinator: NSObject {
        var parent: NativeTextEditor
        var isUpdatingFromView = false
        var loadedDocumentID: UUID?
        /// The text the editor and the binding last agreed on. Comparing
        /// against this avoids reading the whole Scintilla buffer on every
        /// SwiftUI update.
        var lastText: String?
        /// Last reported status, so redundant notifications do not schedule work.
        private var lastLine = -1
        private var lastColumn = -1
        private var lastLineCount = -1

        init(_ parent: NativeTextEditor) { self.parent = parent }

        /// Forces the next notification to be reported, used when the view
        /// starts showing a different document.
        func resetStatusCache() {
            lastLine = -1
            lastColumn = -1
            lastLineCount = -1
        }

        /// Applies the saved caret and scroll position. The scroll position only
        /// takes effect once the view has a size, so it is applied again on the
        /// next run loop after layout.
        func restoreViewState(
            caretPosition: Int,
            firstVisibleLine: Int,
            in editor: CodePad16ScintillaView
        ) {
            editor.setCaretPosition(caretPosition)
            editor.setFirstVisibleLine(firstVisibleLine)
            DispatchQueue.main.async { [weak editor] in
                guard let editor else { return }
                editor.setCaretPosition(caretPosition)
                editor.setFirstVisibleLine(firstVisibleLine)
            }
        }

        func pointersDidChange(_ lines: [NSNumber]) {
            guard !isUpdatingFromView else { return }
            let values = lines.map { $0.intValue }
            let document = parent.document
            Task { @MainActor in
                if document.pointerLines != values {
                    document.pointerLines = values
                }
            }
        }

        func editorDidChange(
            text editedText: String?,
            line: Int,
            column: Int,
            modified: Bool,
            lineCount: Int
        ) {
            // Notifications fired while loading a document (text or lexer assignment)
            // describe the old contents and must not overwrite the incoming document.
            guard !isUpdatingFromView else { return }
            if let editedText, parent.text != editedText {
                lastText = editedText
                parent.text = editedText
            }
            // Scintilla sends updates that change nothing, such as a repaint of
            // the same caret. Skip those instead of scheduling a hop per event.
            guard line != lastLine || column != lastColumn || lineCount != lastLineCount else {
                return
            }
            lastLine = line
            lastColumn = column
            lastLineCount = lineCount
            let document = parent.document
            let controller = parent.controller
            Task { @MainActor in
                if document.lineCount != lineCount {
                    document.lineCount = lineCount
                }
                controller.updateCursorPosition(line: line, column: column)
            }
        }
    }
}
struct CatLogoMark: View {
    var size: CGFloat
    private let ink = Color(red: 20 / 255, green: 34 / 255, blue: 56 / 255)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(LinearGradient(colors: [Color(red: 27 / 255, green: 43 / 255, blue: 66 / 255), Color(red: 12 / 255, green: 20 / 255, blue: 34 / 255)], startPoint: .topLeading, endPoint: .bottomTrailing))
            CatHeadShape()
                .fill(LinearGradient(colors: [Color(red: 167 / 255, green: 242 / 255, blue: 221 / 255), Color(red: 98 / 255, green: 207 / 255, blue: 177 / 255)], startPoint: .topLeading, endPoint: .bottomTrailing))
            HStack(spacing: size * 0.20) {
                Capsule().fill(ink).frame(width: size * 0.075, height: size * 0.14)
                Capsule().fill(ink).frame(width: size * 0.075, height: size * 0.14)
            }
            .offset(y: size * 0.10)
            CatNoseShape()
                .fill(Color(red: 255 / 255, green: 140 / 255, blue: 121 / 255))
                .frame(width: size * 0.12, height: size * 0.065)
                .offset(y: size * 0.21)
            CatMouthShape()
                .stroke(ink.opacity(0.78), style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.21, height: size * 0.105)
                .offset(y: size * 0.285)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct CatHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        var path = Path()
        path.move(to: p(0.24, 0.44))
        path.addLine(to: p(0.19, 0.22))
        path.addLine(to: p(0.43, 0.34))
        path.addQuadCurve(to: p(0.57, 0.34), control: p(0.50, 0.31))
        path.addLine(to: p(0.81, 0.22))
        path.addLine(to: p(0.76, 0.44))
        path.addCurve(to: p(0.78, 0.78), control1: p(0.91, 0.53), control2: p(0.91, 0.68))
        path.addCurve(to: p(0.50, 0.91), control1: p(0.71, 0.91), control2: p(0.60, 0.93))
        path.addCurve(to: p(0.22, 0.78), control1: p(0.40, 0.93), control2: p(0.29, 0.91))
        path.addCurve(to: p(0.24, 0.44), control1: p(0.09, 0.68), control2: p(0.09, 0.53))
        path.closeSubpath()
        return path
    }
}

struct CatNoseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

struct CatMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height * 0.32))
        path.move(to: CGPoint(x: rect.midX, y: rect.height * 0.32))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.72), control: CGPoint(x: rect.width * 0.30, y: rect.maxY))
        path.move(to: CGPoint(x: rect.midX, y: rect.height * 0.32))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.85, y: rect.height * 0.72), control: CGPoint(x: rect.width * 0.70, y: rect.maxY))
        return path
    }
}
