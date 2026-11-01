import SwiftUI

struct ToolRunnerPanel: View {
    @EnvironmentObject private var tools: ToolRunner
    @ObservedObject var controller: EditorController
    let document: EditorDocument?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if tools.selectedToolID == ToolPreset.customID {
                customCommandEditor
                Divider()
            }
            VSplitView {
                outputPane(
                    title: "Response",
                    text: tools.response,
                    placeholder: "The tool's answer appears here.",
                    monospaced: false
                )
                .frame(minHeight: 120, idealHeight: 260, maxHeight: .infinity)

                outputPane(
                    title: "Processing",
                    text: tools.activity,
                    placeholder: "Steps, progress, and errors appear here.",
                    monospaced: true
                )
                .frame(minHeight: 70, idealHeight: 130, maxHeight: .infinity)
            }
            Divider()
            promptEditor
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Picker("Tool", selection: $tools.selectedToolID) {
                ForEach(ToolPreset.all) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 190)
            if tools.isRunning {
                ProgressView()
                    .controlSize(.small)
            }
            Spacer()
            Button {
                tools.clearOutput()
            } label: {
                Image(systemName: "eraser")
            }
            .buttonStyle(.borderless)
            .disabled(tools.isRunning || !tools.hasOutput)
            .help("Clear response and processing")

            Button { tools.isPanelVisible = false } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Close tool runner")
        }
        .padding(10)
    }

    private var customCommandEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField(
                "Command template",
                text: $tools.customCommand,
                prompt: Text("mytool --prompt {prompt}")
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 12, design: .monospaced))
            Text("Placeholders: {prompt} {file} {selection} {directory}")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(10)
    }

    private func outputPane(
        title: String,
        text: String,
        placeholder: String,
        monospaced: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    Text(text.isEmpty ? placeholder : text)
                        .font(monospaced
                            ? .system(size: 11, design: .monospaced)
                            : .system(size: 12))
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    Color.clear
                        .frame(height: 1)
                        .id("bottom-\(title)")
                }
                .onChange(of: text) { _ in
                    proxy.scrollTo("bottom-\(title)", anchor: .bottom)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: monospaced ? .underPageBackgroundColor : .textBackgroundColor))
        }
    }

    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                PromptField(text: $tools.prompt, onSubmit: submit)
                    .frame(height: 64)
                if tools.prompt.isEmpty {
                    Text("Ask the tool…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                        .padding(.leading, 6)
                        .allowsHitTesting(false)
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor))
            )

            Toggle("Include file and selection", isOn: $tools.includeContext)
                .font(.system(size: 11))

            HStack {
                if tools.isRunning {
                    Button("Stop") { tools.cancel() }
                    Spacer()
                    Text("Running…")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("↩ to run · ⇧↩ for a new line")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: submit) {
                        Label("Run", systemImage: "play.fill")
                    }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!tools.canRun)
                }
            }
        }
        .padding(10)
    }

    private func submit() {
        guard tools.canRun else { return }
        tools.run(fileURL: document?.url, selection: controller.selectedText)
    }
}
