import AppKit
import SwiftUI

/// About panel that shows the app version and the README from GitHub.
struct AboutView: View {
    let onClose: () -> Void
    @StateObject private var model = RemoteMarkdownModel(url: AboutView.readmeURL)

    private static let repositoryURL = URL(string: "https://github.com/mpschahal16/codepad16-macos")!
    private static let readmeURL = URL(string: "https://raw.githubusercontent.com/mpschahal16/codepad16-macos/main/README.md")!

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
                Link("Open the README on GitHub", destination: Self.repositoryURL)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        } else {
            ScrollView {
                MarkdownContentView(markdown: model.markdown)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    private var footer: some View {
        HStack {
            Link("View on GitHub", destination: Self.repositoryURL)
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
}
