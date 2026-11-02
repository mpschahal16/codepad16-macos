# CodePad16 release notes

## 0.0.4

Fourth prototype release for Apple Silicon macOS.

### New

- A tool runner panel for OpenCode, Claude Code, Codex, Gemini CLI, or a custom command, sending the active file and selection as context and streaming output into Response and Processing panes
- Word wrap, toggled from the new Editor menu and remembered across launches
- File and Search dropdowns in the header, grouping New, Open, Save, Save As, Open in Other Application, Reveal in Finder, Find, Find Next, and Find Previous
- The find bar reports the current match and the total, such as "2 of 5"
- A Help menu with About, Check for Updates, Release Notes, and License
- About shows the installed version and the project README from GitHub, Release Notes shows what changed, and License shows the bundled GPL text

### Changed

- Updated the vendored editor sources to upstream Scintilla 5.6.8 and Lexilla 5.5.5
- Reduced work on the editor and tool runner hot paths for smoother typing, scrolling, and output streaming
- Editor options now sit before Tools in the header
- Refreshed the README preview image to show the current interface

### Fixed

- Find Next and Find Previous now advance through matches and wrap around the document instead of repeatedly selecting the first match
- Search handles multi-byte text correctly, and the reported match position and total agree with navigation

### Included

- Native macOS editor window with multiple document tabs
- Syntax highlighting for C, C++, C#, Java, JavaScript, TypeScript, Python, Swift, HTML, CSS, JSON, XML, and SQL
- Automatic language detection from the file extension, with a language picker in the status bar
- UTF-8 (with or without a BOM), UTF-16, UTF-32, and ISO-8859-1 file encodings, detected on open, preserved on save, and selectable in the status bar
- Full Unicode text, including accented characters, CJK, and emoji
- Session restore of open tabs with cursor, scroll, language, encoding, and unsaved changes
- Find in the current document with the current match position and total
- Line-number gutter backed by Scintilla
- Cat app icon and current line/column status indicator
- Reopen the editor window from the Dock after closing its last window
- Tool runner panel for command-line agents
- Drag-to-Applications disk image with an arranged Finder layout
- Apple Silicon arm64 application bundle

### Limitations

This is an early prototype. Plugins and advanced search are not included. Swift uses the C-family lexer as an initial approximation. The app is ad-hoc signed and not notarized, so macOS may ask you to confirm the first launch.

The README credits Notepad++ and its author for making the source available; CodePad16 is an independent project and is not an official Notepad++ release.

## 0.0.3

Third prototype release for Apple Silicon macOS.

### New

- Light, dark, and system appearance modes, selectable from the header or the View menu, with matching editor, gutter, caret-line, selection, and syntax colors
- Open a saved file in another application from the File menu or a tab's context menu
- Reveal a saved file in Finder from the File menu or a tab's context menu

### Changed

- Moved the CodePad16 Scintilla bridge into its own target so `Vendor/NotepadPlusPlus` contains only upstream Scintilla and Lexilla sources
- Refreshed the README preview to show the dark editor theme

### Included

- Native macOS editor window with multiple document tabs
- Syntax highlighting for C, C++, C#, Java, JavaScript, TypeScript, Python, Swift, HTML, CSS, JSON, XML, and SQL
- Automatic language detection from the file extension, with a language picker in the status bar
- UTF-8 (with or without a BOM), UTF-16, UTF-32, and ISO-8859-1 file encodings, detected on open, preserved on save, and selectable in the status bar
- Full Unicode text, including accented characters, CJK, and emoji
- Session restore of open tabs with cursor, scroll, language, encoding, and unsaved changes
- Find in the current document
- Line-number gutter backed by Scintilla
- Cat app icon and current line/column status indicator
- Reopen the editor window from the Dock after closing its last window
- Drag-to-Applications disk image with an arranged Finder layout
- Apple Silicon arm64 application bundle

### Limitations

This is an early prototype. Plugins and advanced search are not included. Swift uses the C-family lexer as an initial approximation. The app is ad-hoc signed and not notarized, so macOS may ask you to confirm the first launch.

The README credits Notepad++ and its author for making the source available; CodePad16 is an independent project and is not an official Notepad++ release.

## 0.0.2

Second prototype release for Apple Silicon macOS.

### New

- Syntax highlighting for C, C++, C#, Java, JavaScript, TypeScript, Python, Swift, HTML, CSS, JSON, XML, and SQL
- Automatic language detection from the file extension, with a language picker in the status bar
- UTF-8 (with or without a BOM), UTF-16, UTF-32, and ISO-8859-1 file encodings, detected on open, preserved on save, and selectable in the status bar
- Full Unicode text, including accented characters, CJK, and emoji
- Session restore of open tabs with cursor, scroll, language, encoding, and unsaved changes
- Line-number gutter backed by Scintilla
- Drag-to-Applications disk image with an arranged Finder layout

### Fixed

- Text typed after switching tabs no longer disappears; edits now target the active document
- Unchanged document content is no longer reloaded into the editor during unrelated updates

### Included

- Native macOS editor window with multiple document tabs
- Open, save, and save as for UTF-8 text files
- Find in the current document
- Cat app icon and current line/column status indicator
- Reopen the editor window from the Dock after closing its last window
- Apple Silicon arm64 application bundle

### Limitations

This is an early prototype. Plugins and advanced search are not included. Swift uses the C-family lexer as an initial approximation. The app is ad-hoc signed and not notarized, so macOS may ask you to confirm the first launch.

The README credits Notepad++ and its author for making the source available; CodePad16 is an independent project and is not an official Notepad++ release.

## 0.0.1

First public prototype release for Apple Silicon macOS.

### Included

- Native macOS editor window with multiple document tabs
- Open, save, and save as for UTF-8 text files
- Find in the current document
- Cat app icon and current line/column status indicator
- Reopen the editor window from the Dock after closing its last window
- Apple Silicon arm64 application bundle

### Limitations

This is an early prototype. Syntax highlighting, plugins, session restore, encoding selection, and advanced search are not included. The app is ad-hoc signed and not notarized, so macOS may ask you to confirm the first launch.
