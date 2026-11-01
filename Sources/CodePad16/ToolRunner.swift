import AppKit
import Foundation
import SwiftUI

/// A command-line agent that can be run against the current document.
struct ToolPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let commandTemplate: String

    static let customID = "custom"

    static let builtIns: [ToolPreset] = [
        .init(id: "opencode", name: "OpenCode", commandTemplate: "opencode run {prompt}"),
        .init(id: "claude", name: "Claude Code", commandTemplate: "claude -p {prompt}"),
        .init(id: "codex", name: "Codex", commandTemplate: "codex exec {prompt}"),
        .init(id: "gemini", name: "Gemini CLI", commandTemplate: "gemini -p {prompt}")
    ]

    static let custom = ToolPreset(id: customID, name: "Custom Command", commandTemplate: "")

    static var all: [ToolPreset] { builtIns + [custom] }
}

/// The streamed answer and step log. Kept apart from `ToolRunner` so the fast
/// output updates only invalidate the panel, not the whole window.
@MainActor
final class ToolOutput: ObservableObject {
    @Published fileprivate(set) var response = ""
    @Published fileprivate(set) var activity = ""

    var isEmpty: Bool { response.isEmpty && activity.isEmpty }
}

/// Runs an external command, streams its output, and keeps the panel state.
///
/// Standard output is treated as the tool's answer, and standard error as its
/// progress and diagnostics. Most agent CLIs follow that split: OpenCode, for
/// example, prints its step log to stderr and the final message to stdout.
@MainActor
final class ToolRunner: ObservableObject {
    @Published var isPanelVisible = false
    @Published var selectedToolID: String {
        didSet { defaults.set(selectedToolID, forKey: Keys.tool) }
    }
    @Published var customCommand: String {
        didSet { defaults.set(customCommand, forKey: Keys.customCommand) }
    }
    @Published var includeContext: Bool {
        didSet { defaults.set(includeContext, forKey: Keys.includeContext) }
    }
    @Published var prompt = ""
    @Published private(set) var isRunning = false
    let output = ToolOutput()

    private enum Keys {
        static let tool = "toolRunner.selectedTool"
        static let customCommand = "toolRunner.customCommand"
        static let includeContext = "toolRunner.includeContext"
    }

    private let defaults = UserDefaults.standard
    private var process: Process?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var wasCancelled = false
    /// Output arrives in many small chunks. Chunks are buffered and published at
    /// most once per frame instead of re-laying out the panes per chunk.
    private var pendingResponse = ""
    private var pendingActivity = ""
    private var flushTask: Task<Void, Never>?

    init() {
        selectedToolID = defaults.string(forKey: Keys.tool) ?? ToolPreset.builtIns[0].id
        customCommand = defaults.string(forKey: Keys.customCommand) ?? ""
        includeContext = defaults.object(forKey: Keys.includeContext) as? Bool ?? true
    }

    var selectedPreset: ToolPreset {
        ToolPreset.all.first { $0.id == selectedToolID } ?? ToolPreset.builtIns[0]
    }

    var commandTemplate: String {
        selectedToolID == ToolPreset.customID ? customCommand : selectedPreset.commandTemplate
    }

    var canRun: Bool {
        guard !isRunning else { return false }
        let template = commandTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !template.isEmpty else { return false }
        let hasPrompt = !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasPrompt || !template.contains("{prompt}")
    }

    func run(fileURL: URL?, selection: String) {
        guard canRun else { return }

        let directory = fileURL?.deletingLastPathComponent()
            ?? FileManager.default.homeDirectoryForCurrentUser
        let command = makeCommand(fileURL: fileURL, selection: selection, directory: directory)

        stopStreams()
        flushTask?.cancel()
        flushTask = nil
        pendingResponse.removeAll()
        pendingActivity.removeAll()
        output.response = ""
        output.activity = ""
        isRunning = true
        wasCancelled = false
        appendActivity("Running \(selectedPreset.name)…\n")
        flushPendingOutput()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Login *and* interactive: zsh only reads ~/.zshrc for interactive
        // shells, and that is where tools installed per-user (for example
        // OpenCode in ~/.opencode/bin) usually add themselves to PATH.
        process.arguments = ["-lic", command]
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice
        // The app may have been launched from a terminal, and zsh's
        // /etc/zshrc_Apple_Terminal prints "Restored session: …" to stdout when
        // it sees those variables. They mean nothing to a child process here,
        // and the stray line would land in the answer pane.
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "TERM_PROGRAM")
        environment.removeValue(forKey: "TERM_PROGRAM_VERSION")
        environment.removeValue(forKey: "TERM_SESSION_ID")
        process.environment = environment

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let outHandle = outPipe.fileHandleForReading
        let errHandle = errPipe.fileHandleForReading
        stdoutHandle = outHandle
        stderrHandle = errHandle

        outHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let chunk = String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in self?.appendResponse(chunk) }
        }
        errHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let chunk = String(decoding: data, as: UTF8.self)
            Task { @MainActor [weak self] in self?.appendActivity(chunk) }
        }

        process.terminationHandler = { [weak self] process in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isRunning = false
                self.process = nil
                // The stream handlers stay installed until each pipe reports
                // end of file, so trailing output is not dropped.
                if self.wasCancelled {
                    self.appendActivity("\n[stopped]\n")
                } else if process.terminationStatus != 0 {
                    self.appendActivity("\n[exited with status \(process.terminationStatus)]\n")
                    if process.terminationStatus == 127 {
                        self.appendActivity(
                            "[command not found] Install the tool, or make sure it is on the PATH set by your ~/.zshrc.\n"
                        )
                    }
                } else {
                    self.appendActivity("\n[finished]\n")
                }
                // Publish whatever is still buffered before the run is done.
                self.flushPendingOutput(final: true)
            }
        }

        self.process = process
        do {
            try process.run()
            // The prompt is handed to the tool now; clear the box so the next
            // question starts from an empty field.
            prompt = ""
        } catch {
            isRunning = false
            self.process = nil
            stopStreams()
            appendActivity("Could not run the command: \(error.localizedDescription)\n")
        }
    }

    func cancel() {
        guard let process, process.isRunning else { return }
        wasCancelled = true
        process.terminate()
    }

    func clearOutput() {
        guard !isRunning else { return }
        flushTask?.cancel()
        flushTask = nil
        pendingResponse.removeAll()
        pendingActivity.removeAll()
        output.response = ""
        output.activity = ""
    }

    private func stopStreams() {
        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil
        stdoutHandle = nil
        stderrHandle = nil
    }

    private func makeCommand(fileURL: URL?, selection: String, directory: URL) -> String {
        var fullPrompt = prompt
        if includeContext {
            if let fileURL {
                fullPrompt += "\n\nCurrent file: \(fileURL.path)"
            }
            if !selection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fullPrompt += "\n\nSelected text:\n```\n\(String(selection.prefix(50_000)))\n```"
            }
        }

        return commandTemplate
            .replacingOccurrences(of: "{prompt}", with: Self.shellQuoted(fullPrompt))
            .replacingOccurrences(of: "{file}", with: Self.shellQuoted(fileURL?.path ?? ""))
            .replacingOccurrences(of: "{selection}", with: Self.shellQuoted(selection))
            .replacingOccurrences(of: "{directory}", with: Self.shellQuoted(directory.path))
    }

    private func appendResponse(_ chunk: String) {
        pendingResponse += chunk
        scheduleFlush()
    }

    private func appendActivity(_ chunk: String) {
        pendingActivity += chunk
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        flushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard let self else { return }
            self.flushTask = nil
            // A pipe can deliver its last bytes after the process terminated,
            // so treat flushes after that point as final to release any CR
            // held back for a possible CRLF split.
            self.flushPendingOutput(final: !self.isRunning)
        }
    }

    private func flushPendingOutput(final: Bool = false) {
        flushTask?.cancel()
        flushTask = nil
        flushPending(&pendingResponse, final: final) { text in
            self.output.response = Self.capped(self.output.response + text, limit: 200_000)
        }
        flushPending(&pendingActivity, final: final) { text in
            self.output.activity = Self.capped(self.output.activity + text, limit: 60_000)
        }
    }

    /// Cleans and appends one buffer. Unless this is the final flush, a trailing
    /// carriage return is held back: it may be the first half of a CRLF pair
    /// split across two reads, and normalizing the pair together avoids a
    /// doubled newline.
    private func flushPending(
        _ pending: inout String,
        final: Bool,
        append: (String) -> Void
    ) {
        var body = pending
        var carry = ""
        if !final, body.hasSuffix("\r") {
            body.removeLast()
            carry = "\r"
        }
        pending = carry
        guard !body.isEmpty else { return }
        append(Self.cleaned(body))
    }

    private static func capped(_ text: String, limit: Int) -> String {
        // Counting UTF-8 units is constant time for a native string, while
        // `String.count` walks every character.
        guard text.utf8.count > limit else { return text }
        // Drop well below the limit so trimming happens roughly once per
        // hundred thousand new bytes instead of on every flush.
        return String(text.suffix(limit / 2))
    }

    private static func cleaned(_ chunk: String) -> String {
        var text = chunk
        // Control characters are not grapheme clusters, but checking scalars
        // keeps this correct for any input the stream can produce.
        if text.unicodeScalars.contains("\u{001B}") {
            text = strippingANSI(text)
        }
        // `"\r\n"` is a single Character in Swift, so `text.contains("\r")`
        // would be false for CRLF text and the cleanup below would never run.
        if text.unicodeScalars.contains("\r") {
            text = text
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
        }
        return text
    }

    private static let ansiPattern = try! NSRegularExpression(
        pattern: "\u{001B}\\[[0-?]*[ -/]*[@-~]"
    )

    private static func strippingANSI(_ text: String) -> String {
        ansiPattern.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )
    }

    /// Wraps a value in single quotes so it can be passed safely as one shell argument.
    private static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
