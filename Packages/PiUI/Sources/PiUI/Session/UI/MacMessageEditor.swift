#if os(macOS)
import SwiftUI

/// SwiftUI owns text layout, native editing and hit testing across the whole field.
struct MacMessageEditor: View {
    @Binding var text: String
    let canEdit: Bool
    let canSend: Bool
    let focus: FocusState<Bool>.Binding
    let onSend: @MainActor () -> Void

    @Environment(\.undoManager) private var undoManager
    @State private var selection: TextSelection?
    @State private var returnModifiers: EventModifiers = []

    var body: some View {
        TextField("Say hello", text: $text, selection: $selection, axis: .vertical)
            .lineLimit(2...5)
            .textFieldStyle(.roundedBorder)
            .focused(focus)
            .disabled(!canEdit)
            .accessibilityLabel("Message")
            .accessibilityIdentifier("messageField")
            .onKeyPress(.return, phases: [.down, .repeat]) { press in
                // Let the native field/IME interpret Return first. Only an actual submit
                // command below may send or insert a Shift+Return newline.
                returnModifiers = press.modifiers
                if press.phase == .repeat && press.modifiers.isEmpty { return .handled }
                return .ignored
            }
            .onSubmit {
                defer { returnModifiers = [] }
                guard canEdit, returnModifiers.subtracting(.shift).isEmpty else { return }
                if returnModifiers == .shift {
                    if let edit = MacComposerEdit.insertingNewline(in: text, selection: selection) {
                        MacComposerEdit.apply(edit, text: $text, selection: $selection, undoManager: undoManager)
                    }
                } else if canSend {
                    onSend()
                }
            }
        // Escape is handled by SessionScreen's native SwiftUI exit command. The field
        // and input method get their normal chance to consume it first.
    }
}

/// The only custom edit: replace the selected range with LF, retaining native undo/redo.
/// No second draft model is retained; these values exist only for one edit or undo entry.
struct MacComposerEdit {
    let text: String
    let selection: TextSelection?

    static func insertingNewline(in text: String, selection: TextSelection?) -> Self? {
        let range: Range<String.Index>
        if let selection, case .selection(let selected) = selection.indices { range = selected }
        else { range = text.endIndex..<text.endIndex }
        // During IME confirmation the native selection can still refer to uncommitted
        // text, ahead of the draft binding. Do not edit or index into that stale range.
        let validLower = range.lowerBound == text.endIndex || text.indices.contains(range.lowerBound)
        let validUpper = range.upperBound == text.endIndex || text.indices.contains(range.upperBound)
        guard validLower && validUpper else { return nil }
        let offset = text.distance(from: text.startIndex, to: range.lowerBound)
        var result = text
        result.replaceSubrange(range, with: "\n")
        let caret = result.index(result.startIndex, offsetBy: offset + 1)
        return Self(text: result, selection: TextSelection(insertionPoint: caret))
    }

    @MainActor static func apply(_ edit: Self, text: Binding<String>, selection: Binding<TextSelection?>,
                                 undoManager: UndoManager?) {
        let previous = Self(text: text.wrappedValue, selection: selection.wrappedValue)
        apply(edit, inverse: previous, text: text, selection: selection, undoManager: undoManager)
    }

    @MainActor private static func apply(_ edit: Self, inverse: Self, text: Binding<String>,
                                         selection: Binding<TextSelection?>, undoManager: UndoManager?) {
        if let undoManager {
            undoManager.registerUndo(withTarget: undoManager) { manager in
                MainActor.assumeIsolated {
                    // A parent-supplied Binding getter may capture an older render. Keep
                    // the inverse edit explicitly so redo never rereads that stale draft.
                    apply(inverse, inverse: edit, text: text, selection: selection, undoManager: manager)
                }
            }
        }
        text.wrappedValue = edit.text
        selection.wrappedValue = edit.selection
    }
}
#endif
