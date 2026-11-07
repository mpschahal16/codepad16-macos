# CodePad16 release notes

## 0.0.6

Sixth prototype release for Apple Silicon macOS.

### New

- Workspace sidebar: open one or more folders with ⌥⌘O and browse their files in a narrow tree beside the editor; folders expand lazily, long names scroll horizontally, and the open workspaces are restored on the next launch
- Pinned tabs: pin a tab from the button next to its name or the tab's context menu to keep it at the left of the strip, and Close All Tabs leaves pinned tabs open
- Drag tabs to reorder them; drop on the left or right half of a tab to insert before or after it, or drop in the empty space after the last tab to move it to the end
- Close All Tabs, from the File menu, a tab's context menu, or ⌥⌘W, with a single save or discard prompt
- Rename the current file from the File menu, a tab's context menu, or the workspace sidebar
- Save a Copy As, with ⌥⌘S, writes the buffer to a new file without changing the open tab
- File actions also appear in tab and workspace context menus, and the workspace header has a menu for adding, refreshing, and closing workspaces
- Find in Files opens with the first workspace folder already selected

### Changed

- Opening files from the Finder Open With menu, a drag onto the app icon, or `open -a CodePad16` reuses the existing window and process instead of closing and reopening it; Finder opens bring the window to the front even when the app is hidden, in the background, or minimized
- The app keeps running after its last window closes, so the next Finder open reuses the same process and session
- Opening several files at once makes the last one active and scrolls the tab strip so the active tab is visible
- Pinned tabs are saved with the session, and sessions written before pinning existed still load
- The workspace pane opens narrower and scrolls horizontally instead of widening for long names
- Refreshed the README preview to show the workspace sidebar and the new tab controls

### Included

- Native macOS editor window with multiple document tabs
- Workspace sidebar for one or more folders, with lazy folder expansion and session restore
- Pinned tabs, drag-to-reorder tabs, and Close All Tabs
- Save a Copy As and rename for open files
- Syntax highlighting for C, C++, C#, Java, JavaScript, TypeScript, Python, Swift, HTML, CSS, JSON, XML, and SQL
- Automatic language detection from the file extension, with a language picker in the status bar
- UTF-8 (with or without a BOM), UTF-16, UTF-32, and ISO-8859-1 file encodings, detected on open, preserved on save, and selectable in the status bar
- Full Unicode text, including accented characters, CJK, and emoji
- Session restore of open tabs with cursor, scroll, language, encoding, pin state, and unsaved changes
- Find, replace, and Find in Files across a folder
- Line-number gutter backed by Scintilla
- Cat app icon and current line/column status indicator
- Reopen the editor window from the Dock after closing its last window
- Tool runner panel for command-line agents
- Drag-to-Applications disk image with an arranged Finder layout
- Apple Silicon arm64 application bundle

### Installing

The app is ad-hoc signed and not notarized yet, so macOS may block the first launch with a message that Apple could not verify CodePad16. To open it:

1. Open the downloaded disk image and drag **CodePad16** to **Applications**.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, click **Open Anyway** for CodePad16, and confirm. On macOS 14 and earlier you can also right-click CodePad16 in Finder and choose **Open**.
3. Alternatively, remove the download quarantine in Terminal, then open the app:

   ```sh
   xattr -dr com.apple.quarantine /Applications/CodePad16.app
   ```

Later launches, and updates installed with **Help → Check for Updates**, do not show this prompt.

### Limitations

This is an early prototype. Plugins are not included. Swift uses the C-family lexer as an initial approximation.

The README credits Notepad++ and its author for making the source available; CodePad16 is an independent project and is not an official Notepad++ release.

## 0.0.5

Fifth prototype release for Apple Silicon macOS.

### New

- Replace, Replace All, and a match case option in the find bar, with match case off by default
- Go to Line, from the Search menu or with ⌘L
- Find in Files, a floating results panel that stays open while you open matches; results open on a single or double click, each file group collapses, and the panel can be minimized
- The find and replace fields remember the last 10 terms in a dropdown, and clear when the find bar closes
- Check for Updates downloads the newest release, and Install Update replaces the installed app in place before reopening it
- CodePad16 appears in the Finder Open With menu for text and source files, including HTML, CSS, JSON, XML, and SQL, and opens the chosen file in a tab

### Changed

- About reads the README from GitHub and shows the installed version
- About, Check for Updates, Release Notes, and License also appear in the macOS Help menu
- Documented the first-launch Gatekeeper steps in the README and release notes

### Included

- Native macOS editor window with multiple document tabs
- Syntax highlighting for C, C++, C#, Java, JavaScript, TypeScript, Python, Swift, HTML, CSS, JSON, XML, and SQL
- Automatic language detection from the file extension, with a language picker in the status bar
- UTF-8 (with or without a BOM), UTF-16, UTF-32, and ISO-8859-1 file encodings, detected on open, preserved on save, and selectable in the status bar
- Full Unicode text, including accented characters, CJK, and emoji
- Session restore of open tabs with cursor, scroll, language, encoding, and unsaved changes
- Find, replace, and Find in Files across a folder
- Line-number gutter backed by Scintilla
- Cat app icon and current line/column status indicator
- Reopen the editor window from the Dock after closing its last window
- Tool runner panel for command-line agents
- Drag-to-Applications disk image with an arranged Finder layout
- Apple Silicon arm64 application bundle

### Installing

The app is ad-hoc signed and not notarized yet, so macOS may block the first launch with a message that Apple could not verify CodePad16. To open it:

1. Open the downloaded disk image and drag **CodePad16** to **Applications**.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, click **Open Anyway** for CodePad16, and confirm. On macOS 14 and earlier you can also right-click CodePad16 in Finder and choose **Open**.
3. Alternatively, remove the download quarantine in Terminal, then open the app:

   ```sh
   xattr -dr com.apple.quarantine /Applications/CodePad16.app
   ```

Later launches, and updates installed with **Help → Check for Updates**, do not show this prompt.

### Limitations

This is an early prototype. Plugins are not included. Swift uses the C-family lexer as an initial approximation.

The README credits Notepad++ and its author for making the source available; CodePad16 is an independent project and is not an official Notepad++ release.

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

### Installing

The app is ad-hoc signed and not notarized yet, so macOS may block the first launch with a message that Apple could not verify CodePad16. To open it:

1. Open the downloaded disk image and drag **CodePad16** to **Applications**.
2. Open **System Settings → Privacy & Security**, scroll to **Security**, click **Open Anyway** for CodePad16, and confirm. On macOS 14 and earlier you can also right-click CodePad16 in Finder and choose **Open**.
3. Alternatively, remove the download quarantine in Terminal, then open the app:

   ```sh
   xattr -dr com.apple.quarantine /Applications/CodePad16.app
   ```

Later launches, and updates installed with **Help → Check for Updates**, do not show this prompt.

### Limitations

This is an early prototype. Plugins and advanced search are not included. Swift uses the C-family lexer as an initial approximation.

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
