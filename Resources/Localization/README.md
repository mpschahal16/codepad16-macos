# Adding a language

CodePad16 reads languages from `.lproj` folders in `Resources/Localization`.
Adding a language means adding one folder of translations; no Swift changes are
needed.

## 1. Copy English

Use the two-letter or region-qualified code macOS expects, for example `fr`,
`de`, `es`, `pt-BR`, or `zh-Hans`:

```sh
cp -R Resources/Localization/en.lproj Resources/Localization/fr.lproj
```

## 2. Translate the values

Open `Resources/Localization/fr.lproj/Localizable.strings` and translate only
the text on the right side of each `=`. Keep the keys on the left unchanged.

```text
"Save" = "Enregistrer";
"Version %@" = "Version %@";
```

Important rules:

- Keep every placeholder exactly as it appears in English: `%@`, `%lld`, `%d`,
  `\n`, and punctuation such as `…`.
- Keep the same keys. A missing key falls back to English.
- Do not rename `Localizable.strings`.
- The folder name is what appears in the app's language menu; macOS supplies
  the native language name, for example `Français`.

## 3. Check and rebuild

```sh
plutil -lint Resources/Localization/fr.lproj/Localizable.strings
./scripts/build-app.sh
open dist/CodePad16.app
```

The build script copies every `.lproj` folder into the app and records its code
in `CFBundleLocalizations`. The app discovers the folder at launch, so the new
language appears under **View → Language** automatically.

## Testing a language

Choose **View → Language** and pick the language, or set the saved preference
and relaunch:

```sh
defaults write org.mpschahal16.codepad16 CodePad16.language fr
open dist/CodePad16.app
defaults delete org.mpschahal16.codepad16 CodePad16.language
```

`System` follows the macOS language order and resolves to the first available
translation, falling back to English.

## Notes

- English (`en.lproj`) is the development language and the fallback.
- Some names are brand or product names and stay the same in every language.
- Native AppKit panels and alerts use the same keys through `L10n.t` and
  `L10n.f`; SwiftUI text uses the locale applied by the language picker.
