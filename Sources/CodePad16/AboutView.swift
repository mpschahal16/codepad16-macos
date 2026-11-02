import AppKit
import SwiftUI

@MainActor
final class AboutModel: ObservableObject {
    @Published private(set) var readme = ""
    @Published private(set) var isLoading = true
    @Published private(set) var didFail = false

    static let repositoryURL = URL(string: "https://github.com/mpschahal16/codepad16-macos")!
    static let readmeURL = URL(string: "https://raw.githubusercontent.com/mpschahal16/codepad16-macos/main/README.md")!

    func load() async {
        isLoading = true
        didFail = false
        do {
            let (data, response) = try await URLSession.shared.data(from: Self.readmeURL)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let text = String(data: data, encoding: .utf8) else {
                throw URLError(.badServerResponse)
            }
            readme = text
        } catch {
            didFail = true
        }
        isLoading = false
    }
}

/// About panel that shows the app version and the README from GitHub.
struct AboutView: View {
    let onClose: () -> Void
    @StateObject private var model = AboutModel()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            Divider()
            content
            Divider()
            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .frame(width: 680, height: 580)
        .task { await model.load() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            CatLogoMark(size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("CodePad16")
                    .font(.system(size: 20, weight: .bold))
                Text("Version \(version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("A native macOS text and code editor.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView("Loading README…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.didFail {
            VStack(spacing: 10) {
                Text("Couldn't load the README from GitHub.")
                    .font(.headline)
                Text("Check your network connection and try again.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Link("Open the README on GitHub", destination: AboutModel.repositoryURL)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
        }
    }

    private var footer: some View {
        HStack {
            Link("View on GitHub", destination: AboutModel.repositoryURL)
                .font(.system(size: 12))
            Spacer()
            Button("Close", action: onClose)
                .keyboardShortcut(.defaultAction)
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "unknown"
        if let build = info?["CFBundleVersion"] as? String, build != short {
            return "\(short) (\(build))"
        }
        return short
    }

    // MARK: - README rendering

    private enum Block {
        case heading(String, Int)
        case bullet(String)
        case code(String)
        case paragraph(String)
        case rule
    }

    private var blocks: [Block] {
        var result: [Block] = []
        var codeLines: [String] = []
        var inCode = false

        for rawLine in model.readme.components(separatedBy: .newlines) {
            let line = rawLine.replacingOccurrences(of: "\t", with: "    ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCode {
                    result.append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                }
                inCode.toggle()
                continue
            }
            if inCode {
                codeLines.append(line)
                continue
            }
            if trimmed.isEmpty || trimmed.hasPrefix("![") || trimmed.hasPrefix("<!--") {
                continue
            }
            if let heading = headingBlock(from: trimmed) {
                result.append(heading)
            } else if trimmed == "---" || trimmed == "***" {
                result.append(.rule)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                result.append(.bullet(String(trimmed.dropFirst(2))))
            } else {
                result.append(.paragraph(trimmed))
            }
        }
        if !codeLines.isEmpty {
            result.append(.code(codeLines.joined(separator: "\n")))
        }
        return result
    }

    private func headingBlock(from line: String) -> Block? {
        let level = line.prefix { $0 == "#" }.count
        guard level > 0, level <= 6 else { return nil }
        let text = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return .heading(text, level)
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block {
        case .heading(let text, let level):
            Text(inline(text))
                .font(.system(size: level == 1 ? 22 : level == 2 ? 17 : 15, weight: .semibold))
                .padding(.top, level <= 2 ? 8 : 2)
        case .paragraph(let text):
            Text(inline(text))
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                Text(inline(text))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 12))
        case .code(let text):
            ScrollView(.horizontal, showsIndicators: true) {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        case .rule:
            Divider()
                .padding(.vertical, 4)
        }
    }

    /// Renders the inline Markdown (links, bold, code) while keeping the
    /// surrounding line structure supplied by the block parser.
    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}
