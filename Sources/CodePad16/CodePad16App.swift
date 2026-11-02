import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CodePad16Editor

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
    @StateObject private var appearance = AppearanceSettings()
    @StateObject private var options = EditorOptions()
    @StateObject private var tools = ToolRunner()
    @StateObject private var help = HelpState()
    @NSApplicationDelegateAdaptor(CodePad16AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            CodePad16Window(appDelegate: appDelegate)
                .environmentObject(store)
                .environmentObject(appearance)
                .environmentObject(options)
                .environmentObject(tools)
                .environmentObject(help)
                .frame(minWidth: 760, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Picker("Appearance", selection: $appearance.mode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                Divider()
                Button(tools.isPanelVisible ? "Hide Tool Runner" : "Show Tool Runner") {
                    tools.isPanelVisible.toggle()
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Tab") { store.newDocument() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open…") { store.openFiles() }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    if let document = store.activeDocument { store.save(document) }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(store.activeDocument == nil)
                Button("Save As…") {
                    if let document = store.activeDocument { store.saveAs(document) }
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(store.activeDocument == nil)
                Divider()
                Button("Open in Other Application…") {
                    if let document = store.activeDocument {
                        store.openInOtherApplication(document)
                    }
                }
                .disabled(store.activeDocument == nil)
                Button("Reveal in Finder") {
                    if let document = store.activeDocument {
                        store.revealInFinder(document)
                    }
                }
                .disabled(store.activeDocument?.url == nil)
            }
            CommandGroup(replacing: .help) {
                Button("About CodePad16") { help.showAbout = true }
                Button("Check for Updates…") {
                    NSWorkspace.shared.open(HelpState.latestReleaseURL)
                }
                Divider()
                Button("Release Notes") { help.showReleaseNotes = true }
                Button("License…") { help.showLicense = true }
            }
        }
    }
}

@MainActor
final class CodePad16AppDelegate: NSObject, NSApplicationDelegate {
    var reopenWindow: (() -> Void)?
    var saveSession: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows, let reopenWindow else { return true }
        sender.activate(ignoringOtherApps: true)
        reopenWindow()
        return false
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
    /// Last caret offset and scroll position, updated while the document is shown.
    var caretPosition = 0
    var firstVisibleLine = 0
    /// Line count as reported by the editor, so the status bar does not have to
    /// rescan the whole document whenever the view updates.
    @Published var lineCount: Int
    private var savedText: String

    init(
        text: String = "",
        url: URL? = nil,
        encoding: TextEncoding = .utf8,
        languageMode: LanguageMode? = nil
    ) {
        self.text = text
        self.savedText = text
        self.url = url
        self.encoding = encoding
        self.languageMode = languageMode ?? LanguageMode.detect(url: url)
        self.lineCount = Self.countLines(in: text)
    }

    var title: String { url?.lastPathComponent ?? "Untitled" }
    var displayPath: String { url.map { ($0.path as NSString).abbreviatingWithTildeInPath } ?? "Unsaved" }

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
                        text: text, url: url, encoding: encoding, languageMode: language
                    )
                    document.isDirty = true
                    document.caretPosition = entry.caretPosition
                    document.firstVisibleLine = entry.firstVisibleLine
                    restored.append(document)
                } else if let data = try? Data(contentsOf: url),
                          let (detectedEncoding, text) = TextEncoding.decode(data) {
                    let document = EditorDocument(
                        text: text, url: url, encoding: detectedEncoding, languageMode: language
                    )
                    document.caretPosition = entry.caretPosition
                    document.firstVisibleLine = entry.firstVisibleLine
                    restored.append(document)
                }
            } else {
                let text = entry.text ?? ""
                let document = EditorDocument(
                    text: text, url: nil, encoding: encoding, languageMode: language
                )
                document.isDirty = !text.isEmpty
                document.caretPosition = entry.caretPosition
                document.firstVisibleLine = entry.firstVisibleLine
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
                encodingID: document.encoding.id,
                languageID: document.languageMode.id,
                caretPosition: document.caretPosition,
                firstVisibleLine: document.firstVisibleLine
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

    func openFiles() {
        captureActiveDocument?()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.item]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
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
                        "Could not open \(url.lastPathComponent)",
                        detail: "The file is not valid UTF-8, UTF-16, UTF-32, or ISO-8859-1 text."
                    )
                    continue
                }
                let document = EditorDocument(text: contents, url: url, encoding: encoding)
                documents.append(document)
                activeDocumentID = document.id
            } catch {
                showError("Could not open \(url.lastPathComponent)", detail: error.localizedDescription)
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
        panel.nameFieldStringValue = document.title == "Untitled" ? "Untitled.txt" : document.title
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return write(document, to: url)
    }

    /// Saves pending changes, then lets the user pick an application to open
    /// the file with. Useful for previewing markup or handing a file off to
    /// another editor.
    func openInOtherApplication(_ document: EditorDocument) {
        if document.url == nil || document.isDirty {
            if document.isDirty {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Save changes before opening \(document.title) in another application?"
                alert.informativeText = "The other application will open the saved version of the file."
                alert.addButton(withTitle: "Save and Open")
                alert.addButton(withTitle: "Cancel")
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
        panel.message = "Choose an application to open \(url.lastPathComponent) with."
        panel.prompt = "Open"
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
                    "Could not open \(url.lastPathComponent)",
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
            alert.messageText = "Save changes to \(document.title)?"
            alert.informativeText = "Your edits will be lost if you close this tab without saving."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Discard Changes")
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

    private func write(_ document: EditorDocument, to url: URL) -> Bool {
        guard let data = document.encoding.encode(document.text) else {
            showError(
                "Could not save \(url.lastPathComponent)",
                detail: "Some characters cannot be represented in \(document.encoding.name). Choose UTF-8 in the status bar and save again."
            )
            return false
        }
        do {
            try data.write(to: url, options: .atomic)
            document.markSaved(at: url)
            saveSession()
            return true
        } catch {
            showError("Could not save \(url.lastPathComponent)", detail: error.localizedDescription)
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
    @EnvironmentObject private var appearance: AppearanceSettings
    @EnvironmentObject private var options: EditorOptions
    @EnvironmentObject private var tools: ToolRunner
    @EnvironmentObject private var help: HelpState
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
        .onAppear {
            appearance.apply()
            appDelegate.reopenWindow = { openWindow(id: "main") }
            appDelegate.saveSession = { store.saveSession() }
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
            } label: {
                Label("File", systemImage: "folder")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("File actions")
            Menu {
                Button { windowState.showFind.toggle() } label: { Label("Find…", systemImage: "magnifyingglass") }
                    .keyboardShortcut("f", modifiers: .command)
                Divider()
                Button { findInDocument(backwards: false) } label: { Text("Find Next") }
                    .keyboardShortcut("g", modifiers: .command)
                Button { findInDocument(backwards: true) } label: { Text("Find Previous") }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
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
                .help(tools.isPanelVisible ? "Hide tool runner" : "Show tool runner")
            Menu {
                Button("About CodePad16") { help.showAbout = true }
                Button("Check for Updates…") {
                    NSWorkspace.shared.open(HelpState.latestReleaseURL)
                }
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
        if backwards {
            editorController.findPrevious(windowState.findQuery)
        } else {
            editorController.findNext(windowState.findQuery)
        }
    }

    private var findStatusText: String {
        guard !windowState.findQuery.isEmpty else { return "" }
        let info = editorController.matchInfo(windowState.findQuery)
        guard info.total > 0 else { return "No matches" }
        // A selection past the last match wraps to the first one.
        let index = info.index > 0 ? info.index : 1
        return "\(index) of \(info.total)"
    }

    private var findBar: some View {
        HStack(spacing: 9) {
            TextField("Find in document", text: $windowState.findQuery)
                .textFieldStyle(.roundedBorder)
                .onSubmit { editorController.findNext(windowState.findQuery) }
            Button { editorController.findPrevious(windowState.findQuery) } label: {
                Image(systemName: "chevron.up")
            }
            .help("Previous match")
            Button { editorController.findNext(windowState.findQuery) } label: {
                Image(systemName: "chevron.down")
            }
            .help("Next match")
            Text(findStatusText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button { windowState.showFind = false } label: {
                Image(systemName: "xmark")
            }
            .help("Close Find")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(store.documents) { document in
                    DocumentTab(document: document, isSelected: document.id == store.activeDocumentID) {
                        store.activate(document)
                    } onClose: {
                        store.close(document)
                    }
                    .contextMenu {
                        Button("Open in Other Application…") {
                            store.openInOtherApplication(document)
                        }
                        Button("Reveal in Finder") {
                            store.revealInFinder(document)
                        }
                        .disabled(document.url == nil)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 38)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(alignment: .bottom) { Divider() }
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

    func body(content: Content) -> some View {
        content.navigationTitle("\(document.title) - CodePad16")
    }
}

/// Observes only the document, so typing does not rebuild the whole window.
struct StatusBar: View {
    @ObservedObject var document: EditorDocument
    let controller: EditorController

    var body: some View {
        HStack(spacing: 14) {
            Menu {
                ForEach(LanguageMode.all) { mode in
                    Button {
                        document.languageMode = mode
                    } label: {
                        if document.languageMode.id == mode.id {
                            Label(mode.name, systemImage: "checkmark")
                        } else {
                            Text(mode.name)
                        }
                    }
                }
            } label: {
                Label(document.languageMode.name, systemImage: "chevron.up.chevron.down")
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
                .help(document.url?.path ?? "This document has not been saved yet")
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

    var body: some View {
        HStack(spacing: 7) {
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
        .help(document.url?.path ?? "This document has not been saved yet")
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
    @Published var findQuery = ""
}

/// Shared help state so the in-window Help menu and the macOS Help menu
/// can present the same panels.
@MainActor
final class HelpState: ObservableObject {
    static let latestReleaseURL = URL(string: "https://github.com/mpschahal16/codepad16-macos/releases/latest")!

    @Published var showAbout = false
    @Published var showLicense = false
    @Published var showReleaseNotes = false
}

@MainActor
final class EditorController: ObservableObject {
    weak var scintillaView: CodePad16ScintillaView?
    @Published private(set) var cursorLine = 1
    @Published private(set) var cursorColumn = 1

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
    }

    func findNext(_ query: String) { scintillaView?.find(query, backwards: false) }
    func findPrevious(_ query: String) { scintillaView?.find(query, backwards: true) }

    var selectedText: String { scintillaView?.selectedText ?? "" }

    func matchInfo(_ query: String) -> (index: Int, total: Int) {
        guard let editor = scintillaView else { return (0, 0) }
        let info = editor.matchInfo(query)
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
