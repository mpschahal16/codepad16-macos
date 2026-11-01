import Combine
import Foundation

/// Editor-wide display options. Stored in `UserDefaults` so they survive
/// relaunches and apply to every open document.
@MainActor
final class EditorOptions: ObservableObject {
    private enum Keys {
        static let wordWrap = "editor.wordWrap"
    }

    /// Wrap long lines at the window width instead of scrolling horizontally.
    @Published var wordWrap: Bool {
        didSet {
            guard wordWrap != oldValue else { return }
            UserDefaults.standard.set(wordWrap, forKey: Keys.wordWrap)
        }
    }

    init() {
        wordWrap = UserDefaults.standard.bool(forKey: Keys.wordWrap)
    }
}
