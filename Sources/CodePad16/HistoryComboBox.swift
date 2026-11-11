import AppKit
import SwiftUI

/// An editable combo box that offers the recent searches in the text field's
/// own dropdown, the way Notepad++ does.
struct HistoryComboBox: NSViewRepresentable {
    @Binding var text: String
    let items: [String]
    let placeholder: String
    /// Increment this to move keyboard focus into the field and select its text.
    var focusToken: Int = 0
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSComboBox {
        let combo = NSComboBox()
        combo.isEditable = true
        combo.completes = false
        combo.usesDataSource = false
        combo.numberOfVisibleItems = 10
        combo.placeholderString = placeholder
        combo.bezelStyle = .roundedBezel
        combo.controlSize = .small
        combo.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        combo.lineBreakMode = .byTruncatingTail
        combo.target = context.coordinator
        combo.action = #selector(Coordinator.submit(_:))
        combo.delegate = context.coordinator
        return combo
    }

    func updateNSView(_ combo: NSComboBox, context: Context) {
        context.coordinator.parent = self

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            focus(combo)
        }

        if combo.placeholderString != placeholder {
            combo.placeholderString = placeholder
        }

        let current = combo.objectValues.compactMap { $0 as? String }
        if current != items {
            let typed = combo.stringValue
            combo.removeAllItems()
            combo.addItems(withObjectValues: items)
            combo.stringValue = typed
        }

        if !context.coordinator.isUpdating, combo.stringValue != text {
            combo.stringValue = text
        }
    }

    /// Moves focus into the combo box once it is part of a window. When the bar
    /// is first shown, the view can be created before SwiftUI attaches it, so
    /// retry on the next run loop(s) instead of silently doing nothing.
    private func focus(_ combo: NSComboBox, attempts: Int = 20) {
        DispatchQueue.main.async { [weak combo] in
            guard let combo else { return }
            guard let window = combo.window else {
                if attempts > 0 { self.focus(combo, attempts: attempts - 1) }
                return
            }
            window.makeFirstResponder(combo)
            combo.selectText(nil)
        }
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: HistoryComboBox
        var isUpdating = false
        var lastFocusToken = 0

        init(_ parent: HistoryComboBox) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let combo = notification.object as? NSComboBox else { return }
            isUpdating = true
            parent.text = combo.stringValue
            isUpdating = false
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let combo = notification.object as? NSComboBox else { return }
            isUpdating = true
            parent.text = combo.stringValue
            isUpdating = false
        }

        @objc func submit(_ sender: Any?) {
            guard let combo = sender as? NSComboBox else {
                parent.onSubmit()
                return
            }
            isUpdating = true
            parent.text = combo.stringValue
            isUpdating = false
            parent.onSubmit()
        }
    }
}
