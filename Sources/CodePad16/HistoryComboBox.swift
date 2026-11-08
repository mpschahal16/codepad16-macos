import AppKit
import SwiftUI

/// An editable combo box that offers the recent searches in the text field's
/// own dropdown, the way Notepad++ does.
struct HistoryComboBox: NSViewRepresentable {
    @Binding var text: String
    let items: [String]
    let placeholder: String
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

    final class Coordinator: NSObject, NSComboBoxDelegate {
        var parent: HistoryComboBox
        var isUpdating = false

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
