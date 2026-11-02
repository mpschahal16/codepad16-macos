import AppKit
import SwiftUI

/// Loads a Markdown document from a URL for the Help panels.
@MainActor
final class RemoteMarkdownModel: ObservableObject {
    @Published private(set) var markdown = ""
    @Published private(set) var isLoading = true
    @Published private(set) var didFail = false

    private let url: URL

    init(url: URL) {
        self.url = url
    }

    func load() async {
        isLoading = true
        didFail = false
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let text = String(data: data, encoding: .utf8) else {
                throw URLError(.badServerResponse)
            }
            markdown = text
        } catch {
            didFail = true
        }
        isLoading = false
    }
}

/// Line-based Markdown renderer used by the About and Release Notes panels.
struct MarkdownContentView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

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

        for rawLine in markdown.components(separatedBy: .newlines) {
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
