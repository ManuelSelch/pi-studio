#if os(macOS)
import AppKit
import SwiftUI

/// Native text storage is only the editing surface for the composer's local binding.
/// Command interception stays in this text view's responder path, never on a window.
struct MacMessageEditor: NSViewRepresentable {
    @Binding var text: String
    let canEdit: Bool
    let canSend: Bool
    let canStop: Bool
    let focus: FocusState<Bool>.Binding
    let onSend: @MainActor () -> Void
    let onStop: @MainActor () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.hasHorizontalScroller = false
        scroll.drawsBackground = true
        scroll.backgroundColor = .textBackgroundColor
        let editor = ComposerTextView(frame: .zero)
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.font = .preferredFont(forTextStyle: .body)
        editor.textColor = .textColor
        editor.backgroundColor = .textBackgroundColor
        editor.textContainerInset = NSSize(width: 6, height: 6)
        editor.isHorizontallyResizable = false
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        editor.setAccessibilityLabel("Message")
        editor.setAccessibilityIdentifier("messageField")
        editor.delegate = context.coordinator
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? ComposerTextView else { return }
        editor.canSend = canSend
        editor.canStop = canStop
        editor.onSend = onSend
        editor.onStop = onStop
        editor.onFocusChanged = { [weak coordinator = context.coordinator, weak editor] in
            // First-responder changes can occur during SwiftUI updates. Read the
            // current responder later instead of replaying an obsolete focus event.
            DispatchQueue.main.async {
                guard let coordinator, let editor else { return }
                coordinator.parent.focus.wrappedValue = editor.window?.firstResponder === editor
            }
        }
        // Keep the responder/selection while generation temporarily locks editing.
        editor.isEditable = canEdit
        editor.isSelectable = true
        // A locked composer must look locked: otherwise it silently swallows every keystroke.
        editor.backgroundColor = canEdit ? .textBackgroundColor : .controlBackgroundColor
        editor.textColor = canEdit ? .textColor : .secondaryLabelColor
        // The accessibility *value* of a text view is its text, so the locked state is exposed
        // as help instead; the visible hint explains it too.
        editor.setAccessibilityHelp(canEdit ? "Type a message" : "Read only until the run settles")
        // Only adopt text that did not come from this editor. A render that still carries the
        // previous value must not revert what the user just typed.
        if text != context.coordinator.reportedText, !editor.hasMarkedText() {
            editor.string = text
            editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            editor.undoManager?.removeAllActions()
            editor.scrollRangeToVisible(editor.selectedRange())
            context.coordinator.reportedText = text
        }
        // Honor explicit focus transitions, not every streaming render: the user
        // may have moved focus before the deferred binding notification arrives.
        if focus.wrappedValue, !context.coordinator.wasFocused,
           editor.window?.firstResponder !== editor {
            editor.window?.makeFirstResponder(editor)
        } else if !focus.wrappedValue, context.coordinator.wasFocused,
                  editor.window?.firstResponder === editor {
            editor.window?.makeFirstResponder(nil)
        }
        context.coordinator.wasFocused = focus.wrappedValue
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        guard let editor = scroll.documentView as? ComposerTextView else { return }
        editor.delegate = nil
        editor.onFocusChanged = nil
        editor.onSend = {}; editor.onStop = {}
        editor.undoManager?.removeAllActions()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView scroll: NSScrollView,
                      context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0,
              let editor = scroll.documentView as? NSTextView,
              let container = editor.textContainer, let layout = editor.layoutManager else { return nil }
        let contentWidth = max(1, width - 4)
        editor.setFrameSize(NSSize(width: contentWidth, height: editor.frame.height))
        container.containerSize = NSSize(width: max(1, contentWidth - 2 * editor.textContainerInset.width),
                                         height: CGFloat.greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let lineHeight = layout.defaultLineHeight(for: editor.font ?? .systemFont(ofSize: 13))
        // Include the extra empty line after a trailing newline, keeping its caret visible.
        let usedHeight = max(layout.usedRect(for: container).height, layout.extraLineFragmentRect.maxY)
        let fullHeight = max(2 * lineHeight, usedHeight)
        editor.setFrameSize(NSSize(width: contentWidth, height: ceil(fullHeight + 2 * editor.textContainerInset.height)))
        let lines = min(5 * lineHeight, fullHeight)
        return CGSize(width: width, height: ceil(lines + 2 * editor.textContainerInset.height + 4))
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MacMessageEditor
        var wasFocused = false
        /// The last text this editor reported to the binding, so external changes (a tab switch
        /// or an admitted send) still apply while a stale render cannot revert typing.
        var reportedText: String?
        init(_ parent: MacMessageEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
            reportedText = editor.string
            editor.scrollRangeToVisible(editor.selectedRange())
        }
    }
}

@MainActor private final class ComposerTextView: NSTextView {
    var canSend = false
    var canStop = false
    var onSend: @MainActor () -> Void = {}
    var onStop: @MainActor () -> Void = {}
    var onFocusChanged: (@MainActor () -> Void)?
    private let localUndoManager = UndoManager()
    override var undoManager: UndoManager? { localUndoManager }
    private var interpretingEvent: NSEvent?
    private var startedWithMarkedText = false

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChanged?() }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { onFocusChanged?() }
        return accepted
    }

    override func keyDown(with event: NSEvent) {
        interpretingEvent = event
        startedWithMarkedText = hasMarkedText()
        defer { interpretingEvent = nil; startedWithMarkedText = false }
        if !isEditable, event.keyCode == 53 {
            // A read-only text view can skip normal editing command dispatch.
            // Keep Escape in the local command path while a run locks editing.
            interpretKeyEvents([event])
        } else { super.keyDown(with: event) }
    }

    override func doCommand(by selector: Selector) {
        guard let event = interpretingEvent else { super.doCommand(by: selector); return }
        let key: MacComposerKey
        if event.keyCode == 53 {
            // Native key bindings can map Escape to cancelOperation or complete.
            key = .escape
        } else if ["insertNewline:", "insertNewlineIgnoringFieldEditor:", "insertLineBreak:"].contains(NSStringFromSelector(selector)) {
            key = .returnKey
        } else { super.doCommand(by: selector); return }
        var modifiers: MacComposerModifiers = []
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        let command = MacComposerCommand.resolve(
            key: key, modifiers: modifiers,
            isComposing: startedWithMarkedText || hasMarkedText(), isRepeat: event.isARepeat,
            canEdit: isEditable, canSend: canSend, canStop: canStop)
        switch command {
        case .native:
            if key == .returnKey, modifiers == .shift,
               !startedWithMarkedText, !hasMarkedText() {
                // Always insert a native LF newline, even if a key binding maps
                // Shift+Return to insertLineBreak (a Unicode line separator).
                super.insertNewline(nil)
            } else { super.doCommand(by: selector) }
        case .consume: break
        case .submit: onSend()
        case .stop: onStop()
        }
    }
}
#endif
