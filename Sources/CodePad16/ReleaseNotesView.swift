import AppKit
import SwiftUI

/// Shows the release notes from GitHub.
struct ReleaseNotesView: View {
    let onClose: () -> Void
    @StateObject private var model = RemoteMarkdownModel(url: ReleaseNotesView.notesURL)

    private static let releasesURL = URL(string: "https://github.com/mpschahal16/codepad16-macos/releases")!
    private static let notesURL = URL(string: "https://raw.githubusercontent.com/mpschahal16/codepad16-macos/main/RELEASE_NOTES.md")!

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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Release Notes")
                    .font(.system(size: 20, weight: .bold))
                Text("What's new in CodePad16. Installed version \(version).")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Link("View all releases on GitHub", destination: Self.releasesURL)
                    .font(.system(size: 12))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading {
            ProgressView("Loading release notes…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.didFail {
            VStack(spacing: 10) {
                Text("Couldn't load the release notes from GitHub.")
                    .font(.headline)
                Text("Check your network connection and try again.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Link("View releases on GitHub", destination: Self.releasesURL)
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
