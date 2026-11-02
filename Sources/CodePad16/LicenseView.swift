import AppKit
import SwiftUI

/// Shows the project license bundled with the app.
struct LicenseView: View {
    let onClose: () -> Void
    private let licenseText: String?

    private static let licenseURL = URL(string: "https://github.com/mpschahal16/codepad16-macos/blob/main/LICENSE")!

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            licenseText = text
        } else {
            licenseText = nil
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("License")
                    .font(.system(size: 20, weight: .bold))
                Text("CodePad16 is free software under the GNU General Public License v3.0 or later.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Link("Read the license on GitHub", destination: Self.licenseURL)
                    .font(.system(size: 12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            Divider()
            if let licenseText {
                ScrollView {
                    Text(licenseText)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                }
            } else {
                VStack(spacing: 10) {
                    Text("The license file isn't available in this build.")
                        .font(.headline)
                    Link("Read the license on GitHub", destination: Self.licenseURL)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            HStack {
                Spacer()
                Button("Close", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 680, height: 560)
    }
}
