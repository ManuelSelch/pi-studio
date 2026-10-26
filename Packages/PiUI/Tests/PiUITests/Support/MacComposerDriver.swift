#if os(macOS)
import AppKit
import SwiftUI
import Testing

/// Hosted native editors share AppKit focus/field-editor machinery; serialize their scenarios.
@Suite(.serialized)
struct MacComposerTests {}

/// In-process, off-screen driver. Never activates a window or posts system input.
@MainActor
final class MacComposerDriver {
    private let hosting: NSHostingView<AnyView>
    private let window: NSWindow

    init<V: View>(_ view: V, width: CGFloat = 760) {
        hosting = NSHostingView(rootView: AnyView(view))
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: 520)
        window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
    }

    private func field(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField { return field }
        return view.subviews.lazy.compactMap { self.field(in: $0) }.first
    }

    private func input() throws -> NSTextField {
        hosting.layoutSubtreeIfNeeded()
        return try #require(field(in: hosting), "The SwiftUI composer must expose its native field")
    }

    private func editor() throws -> NSTextView {
        let input = try input()
        if input.currentEditor() == nil { window.makeFirstResponder(input) }
        return try #require(input.currentEditor() as? NSTextView)
    }

    func settle() async throws {
        // Allow SwiftUI to publish binding/selection updates without a visible window.
        try await Task.sleep(for: .milliseconds(30))
        hosting.layoutSubtreeIfNeeded()
    }

    func type(_ text: String) async throws {
        try await settle()
        let editor = try editor()
        editor.insertText(text, replacementRange: editor.selectedRange())
        try await settle()
    }

    func beginComposition(_ text: String) async throws {
        try await settle()
        let editor = try editor()
        editor.setMarkedText(text, selectedRange: NSRange(location: text.utf16.count, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        editor.didChangeText()
        try await settle()
    }

    func select(_ range: NSRange) async throws {
        try editor().setSelectedRange(range)
        try await settle()
    }

    func pressReturn(shift: Bool = false, repeating: Bool = false) async throws {
        _ = try editor()
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: shift ? .shift : [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: repeating, keyCode: 36))
        window.sendEvent(event)
        try await settle()
    }

    func undo() async throws {
        window.undoManager?.undo()
        try await settle()
    }

    func redo() async throws {
        window.undoManager?.redo()
        try await settle()
    }

    func pressEscape(repeating: Bool = false, shift: Bool = false) async throws {
        if window.firstResponder === window { window.makeFirstResponder(hosting) }
        let event = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: shift ? .shift : [], timestamp: 0, windowNumber: window.windowNumber,
            context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: repeating, keyCode: 53))
        window.sendEvent(event)
        try await settle()
    }

    func textShouldBe(_ expected: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let input = try input()
        let actual = (input.currentEditor() as? NSTextView)?.string ?? input.stringValue
        #expect(actual == expected, sourceLocation: sourceLocation)
    }

    func editingShouldBeEnabled(_ expected: Bool, sourceLocation: SourceLocation = #_sourceLocation) throws {
        #expect(try input().isEnabled == expected, sourceLocation: sourceLocation)
    }

    func wholeWidthShouldAcceptClicks(sourceLocation: SourceLocation = #_sourceLocation) throws {
        let input = try input()
        #expect(input.bounds.width > 200, sourceLocation: sourceLocation)
        for fraction in [0.05, 0.5, 0.95] {
            let point = NSPoint(x: input.bounds.width * fraction, y: input.bounds.midY)
            let hit = input.hitTest(input.convert(point, to: input.superview))
            #expect(hit === input || hit?.isDescendant(of: input) == true, sourceLocation: sourceLocation)
        }
        let editor = try editor()
        #expect(editor.frame.width >= input.bounds.width - 16, sourceLocation: sourceLocation)
        #expect(!window.isVisible, sourceLocation: sourceLocation)
    }
}
#endif
