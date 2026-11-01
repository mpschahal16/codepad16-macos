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
    @Published private(set) var response = ""
    @Published private(set) var activity = ""
    @Published private(set) var isRunning = false

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

    var hasOutput: Bool { !response.isEmpty || !activity.isEmpty }

    func run(fileURL: URL?, selection: String) {
        guard canRun else { return }

        let directory = fileURL?.deletingLastPathComponent()
            ?? FileManager.default.homeDirectoryForCurrentUser
        let command = makeCommand(fileURL: fileURL, selection: selection, directory: directory)

        stopStreams()
        response = ""
        activity = ""
        isRunning = true
        wasCancelled = false
        appendActivity("Running \(selectedPreset.name)…\n")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Login *and* interactive: zsh only reads ~/.zshrc for interactive
        // shells, and that is where tools installed per-user (for example
        // OpenCode in ~/.opencode/bin) usually add themselves to PATH.
        process.arguments = ["-lic", command]
        process.currentDirectoryURL = directory
        process.standardInput = FileHandle.nullDevice

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
        response = ""
        activity = ""
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
        response = Self.capped(response + Self.cleaned(chunk), limit: 500_000)
    }

    private func appendActivity(_ chunk: String) {
        activity = Self.capped(activity + Self.cleaned(chunk), limit: 200_000)
    }

    private static func capped(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        return String(text.suffix(limit * 4 / 5))
    }

    private static func cleaned(_ chunk: String) -> String {
        strippingANSI(chunk)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
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
