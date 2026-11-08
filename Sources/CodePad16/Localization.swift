import Foundation
import SwiftUI

/// A language that ships with the app. The identifier is the name of the
/// `.lproj` folder, and the name is shown in the language menu in that
/// language (for example "हिन्दी"), so the menu is readable before switching.
struct AppLanguage: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Loads `Localizable.strings` from the `.lproj` folders in the app bundle and
/// lets the UI switch between them without relaunching.
///
/// English is the development language and the fallback for any key a
/// translation does not provide. Adding a language does not require code
/// changes: copy `Resources/Localization/en.lproj` to a new folder, translate
/// its values, and rebuild.
final class Localization: ObservableObject {
    static let shared = Localization()
    static let systemID = "system"

    private static let defaultsKey = "CodePad16.language"

    /// The user's choice: a language code, or `systemID`.
    @Published private(set) var selection: String
    /// The code actually in use, with `systemID` resolved to a language.
    @Published private(set) var languageID: String
    /// Passed to SwiftUI so `Text`, `Button`, and other localized literals
    /// follow the selected language.
    @Published private(set) var locale: Locale
    /// Languages found in the bundle, English first.
    let available: [AppLanguage]

    private let bundles: [String: Bundle]
    private let lock = NSLock()
    private var currentID: String

    private init() {
        let codes = Self.availableCodes()
        bundles = Dictionary(uniqueKeysWithValues: codes.compactMap { code in
            Bundle.main.path(forResource: code, ofType: "lproj")
                .flatMap(Bundle.init(path:))
                .map { (code, $0) }
        })

        available = codes.map { code in
            let name = Locale(identifier: code).localizedString(forIdentifier: code) ?? code
            return AppLanguage(id: code, name: name)
        }

        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey) ?? Self.systemID
        let resolved = Self.resolve(saved, from: codes)
        selection = saved == Self.systemID ? Self.systemID : resolved
        languageID = resolved
        locale = Locale(identifier: resolved)
        currentID = resolved
    }

    /// Switches languages immediately and stores the choice for the next launch.
    func select(_ id: String) {
        let codes = available.map(\.id)
        let resolved: String
        if id == Self.systemID {
            resolved = Self.systemPreferred(from: codes)
        } else if codes.contains(id) {
            resolved = id
        } else {
            resolved = Self.systemPreferred(from: codes)
        }

        let stored = id == Self.systemID ? Self.systemID : resolved
        guard stored != selection || resolved != languageID else { return }

        lock.lock()
        currentID = resolved
        lock.unlock()

        selection = stored
        languageID = resolved
        locale = Locale(identifier: resolved)
        UserDefaults.standard.set(stored, forKey: Self.defaultsKey)
    }

    /// Looks up a string in the selected language, then English, then the key.
    /// Use this for AppKit strings and for strings stored outside a SwiftUI
    /// view; SwiftUI literals are localized automatically through `locale`.
    func t(_ key: String) -> String {
        lock.lock()
        let language = currentID
        lock.unlock()

        if let bundle = bundles[language] {
            let value = bundle.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        if language != "en", let english = bundles["en"] {
            let value = english.localizedString(forKey: key, value: nil, table: nil)
            if value != key { return value }
        }
        return key
    }

    /// Formats a localized string. Keep the same `%@`, `%lld`, and `%d`
    /// placeholders in every translation.
    func format(_ key: String, _ arguments: [CVarArg]) -> String {
        String(format: t(key), arguments: arguments)
    }

    /// Variadic convenience used from views.
    func f(_ key: String, _ arguments: CVarArg...) -> String {
        format(key, arguments)
    }

    private static func resolve(_ saved: String, from codes: [String]) -> String {
        if saved != systemID, codes.contains(saved) { return saved }
        return systemPreferred(from: codes)
    }

    private static func systemPreferred(from codes: [String]) -> String {
        Bundle.preferredLocalizations(from: codes).first
            ?? codes.first
            ?? "en"
    }

    /// Reads the `.lproj` folders in the app bundle. `Bundle.localizations`
    /// skips languages whose resources are only copied in at build time, so
    /// the folder listing is the source of truth when it is available.
    private static func availableCodes() -> [String] {
        var codes: Set<String> = []

        if let resourceURL = Bundle.main.resourceURL,
           let items = try? FileManager.default.contentsOfDirectory(
               at: resourceURL,
               includingPropertiesForKeys: nil
           ) {
            for item in items where item.pathExtension == "lproj" {
                let code = item.deletingPathExtension().lastPathComponent
                if code != "Base" { codes.insert(code) }
            }
        }

        if codes.isEmpty {
            codes = Set(Bundle.main.localizations.filter { $0 != "Base" })
        }
        if codes.isEmpty { codes = ["en"] }

        var ordered = codes.sorted()
        if let english = ordered.firstIndex(of: "en") {
            ordered.remove(at: english)
            ordered.insert("en", at: 0)
        }
        return ordered
    }
}

/// Convenience accessors used throughout the app.
enum L10n {
    static func t(_ key: String) -> String {
        Localization.shared.t(key)
    }

    static func f(_ key: String, _ arguments: CVarArg...) -> String {
        Localization.shared.format(key, arguments)
    }
}
