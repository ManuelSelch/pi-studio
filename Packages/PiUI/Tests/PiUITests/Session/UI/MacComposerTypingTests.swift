#if os(macOS)
import AppKit
import Flux
import Foundation
import PiSDK
import SwiftUI
import Testing
@testable import PiUI

/// macOS UI automation is paused by user request, so the composer's typing path is covered
/// here instead: a store-backed draft, the real `SessionScreen`, and a hosted text view.
@MainActor
struct MacComposerTypingTests {
    /// Mirrors the app: the container observes the workspace store and rebuilds the screen, so
    /// `updateNSView` runs after every state change.
    private struct Harness: View {
        @ObservedObject var workspace: FluxStore<WorkspaceFeature>
        let canEdit: Bool
        let hint: String

        var body: some View {
            var presentation = SessionPresentation()
            presentation.draft = workspace.state.draft
            presentation.hint = hint
            presentation.canEditMessage = canEdit
            presentation.canSend = canEdit
            presentation.placeholder = "Start a conversation."
            return SessionScreen(presentation: presentation,
                                 onDraftChanged: { workspace.dispatch(.draftChanged($0)) },
                                 onConnect: {}, onDisconnect: {}, onSend: { _ in }, onStop: {},
                                 showsHeader: false, maxContentWidth: 760)
        }
    }

    @MainActor private struct Fixture {
        let workspace: FluxStore<WorkspaceFeature>
        let window: NSWindow
        let editor: NSTextView
    }

    private func fixture(canEdit: Bool = true, hint: String = "") throws -> Fixture {
        let workspace = FluxStore<WorkspaceFeature>(state: .init())
        let tab = OpenSession(identity: OpenSessionIdentity(scope: "scope", sessionPath: nil,
                                                           runtimeId: "runtime", projectPath: "/repo"),
                              title: "Session")
        workspace.dispatch(.opened(workspace.state.generation, tab))
        let hosting = NSHostingView(rootView: Harness(workspace: workspace, canEdit: canEdit, hint: hint))
        hosting.frame = NSRect(x: 0, y: 0, width: 760, height: 520)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        let editor = try #require(textView(in: hosting), "The composer must host a text view")
        return Fixture(workspace: workspace, window: window, editor: editor)
    }

    /// Types the way a keystroke does: mutate the text view, then let it notify its delegate.
    private func type(_ text: String, into editor: NSTextView, window: NSWindow) {
        editor.string += text
        editor.didChangeText()
        window.contentView?.layoutSubtreeIfNeeded()
    }

    private func textView(in view: NSView) -> NSTextView? {
        if let editor = view as? NSTextView { return editor }
        for subview in view.subviews {
            if let found = textView(in: subview) { return found }
        }
        return nil
    }

    @Test func typingReachesTheStoreBackedDraftAndSurvivesRendering() throws {
        let fixture = try fixture()
        type("hello", into: fixture.editor, window: fixture.window)
        #expect(fixture.workspace.state.draft == "hello")
        #expect(fixture.editor.string == "hello")
        type(" world", into: fixture.editor, window: fixture.window)
        #expect(fixture.workspace.state.draft == "hello world")
        #expect(fixture.editor.string == "hello world")
    }

    @Test func anExternalDraftChangeIsAdopted() throws {
        let fixture = try fixture()
        type("draft", into: fixture.editor, window: fixture.window)
        #expect(fixture.workspace.state.draft == "draft")
        // Selecting another tab replaces the text, and an admitted send clears it.
        fixture.workspace.dispatch(.draftChanged("other tab"))
        fixture.window.contentView?.layoutSubtreeIfNeeded()
        #expect(fixture.editor.string == "other tab")
        fixture.workspace.dispatch(.draftChanged(""))
        fixture.window.contentView?.layoutSubtreeIfNeeded()
        #expect(fixture.editor.string == "")
    }

    @Test func aLockedComposerRefusesInputAndShowsTheReason() throws {
        let fixture = try fixture(canEdit: false, hint: "Generating… Stop to edit.")
        #expect(!fixture.editor.isEditable)
        #expect(fixture.editor.accessibilityHelp() == "Read only until the run settles")
        // A locked composer must not silently accept keystrokes either.
        fixture.editor.insertText("blocked", replacementRange: fixture.editor.selectedRange())
        #expect(fixture.editor.string.isEmpty)
        #expect(fixture.workspace.state.draft.isEmpty)
    }
}
#endif
