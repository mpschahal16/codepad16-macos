import AppKit
import SwiftUI

/// The window appearance the user picked. Stored in `UserDefaults` so the
/// choice survives relaunches, independently of the document session.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.t("System")
        case .light: return L10n.t("Light")
        case .dark: return L10n.t("Dark")
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// `nil` follows the system setting for AppKit panels and alerts too.
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
final class AppearanceSettings: ObservableObject {
    @Published var mode: AppearanceMode {
        didSet {
            guard mode != oldValue else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: AppearanceMode.storageKey)
            apply()
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: AppearanceMode.storageKey)
        mode = stored.flatMap(AppearanceMode.init(rawValue:)) ?? .system
        // Set AppKit's appearance before the first window is shown so it does
        // not flash the system appearance when a different mode is stored.
        NSApplication.shared.appearance = mode.nsAppearance
    }

    /// Applies the choice to AppKit as well, so open/save panels, alerts, and
    /// the embedded Scintilla editor follow the selected appearance.
    func apply() {
        let appearance = mode.nsAppearance
        NSApplication.shared.appearance = appearance
        // Updating each window explicitly makes `.system` reliably return to
        // the current system appearance instead of keeping the last override.
        for window in NSApplication.shared.windows {
            window.appearance = appearance
        }
    }
}
