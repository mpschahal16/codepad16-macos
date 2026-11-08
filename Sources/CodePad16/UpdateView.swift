import AppKit
import SwiftUI

/// Software update panel shown by Check for Updates.
struct UpdateView: View {
    let onClose: () -> Void
    @ObservedObject var checker: UpdateChecker
    @EnvironmentObject private var localization: Localization

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
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 460, height: 300)
    }

    @ViewBuilder
    private var icon: some View {
        switch checker.phase {
        case .idle, .checking, .downloading, .installing:
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
            return localization.t("Checking for Updates…")
        case .upToDate:
            return localization.t("You're up to date")
        case .downloading(let version):
            return localization.f("Downloading CodePad16 %@…", version)
        case .downloaded(let version, _):
            return localization.f("CodePad16 %@ downloaded", version)
        case .installing(let version):
            return localization.f("Installing CodePad16 %@…", version)
        case .failed:
            return localization.t("Couldn't check for updates")
        }
    }

    private var message: String {
        switch checker.phase {
        case .idle, .checking:
            return localization.t("Looking for the latest release on GitHub.")
        case .upToDate(let current, let latest):
            return latest == current
                ? localization.f("CodePad16 %@ is the latest version.", current)
                : localization.f("CodePad16 %@ is the latest version; you have %@.", latest, current)
        case .downloading:
            return localization.t("The disk image will be saved to your Downloads folder.")
        case .downloaded(_, let file):
            return localization.f("Saved to %@", file.path)
        case .installing:
            return localization.t("CodePad16 will quit and reopen when the update is installed.")
        case .failed(let reason):
            return reason
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch checker.phase {
        case .downloaded(_, let file):
            HStack(spacing: 10) {
                Button("Install Update") {
                    checker.installDownloadedUpdate()
                }
                .keyboardShortcut(.defaultAction)
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
