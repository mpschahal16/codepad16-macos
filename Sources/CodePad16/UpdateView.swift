import AppKit
import SwiftUI

/// Software update panel shown by Check for Updates.
struct UpdateView: View {
    let onClose: () -> Void
    @ObservedObject var checker: UpdateChecker

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                icon
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                actions
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
            Divider()
            HStack {
                Link("View releases on GitHub", destination: checker.releasePageURL)
                    .font(.system(size: 12))
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 460, height: 300)
    }

    @ViewBuilder
    private var icon: some View {
        switch checker.phase {
        case .idle, .checking, .downloading:
            ProgressView()
                .controlSize(.large)
        case .upToDate:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
        case .downloaded:
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.blue)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
        }
    }

    private var title: String {
        switch checker.phase {
        case .idle, .checking:
            return "Checking for Updates…"
        case .upToDate:
            return "You're up to date"
        case .downloading(let version):
            return "Downloading CodePad16 \(version)…"
        case .downloaded(let version, _):
            return "CodePad16 \(version) downloaded"
        case .failed:
            return "Couldn't check for updates"
        }
    }

    private var message: String {
        switch checker.phase {
        case .idle, .checking:
            return "Looking for the latest release on GitHub."
        case .upToDate(let current, let latest):
            return latest == current
                ? "CodePad16 \(current) is the latest version."
                : "CodePad16 \(latest) is the latest version; you have \(current)."
        case .downloading:
            return "The disk image will be saved to your Downloads folder."
        case .downloaded(_, let file):
            return "Saved to \(file.path)"
        case .failed(let reason):
            return reason
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch checker.phase {
        case .downloaded(_, let file):
            HStack(spacing: 10) {
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([file])
                }
                Button("Open") {
                    NSWorkspace.shared.open(file)
                }
            }
            .padding(.top, 4)
        default:
            EmptyView()
        }
    }
}
