#if os(macOS)
import Flux
import Foundation
import SwiftUI
import Testing
@testable import PiUI

extension MacComposerTests {
@MainActor
struct MacComposerTypingTests {
    @MainActor private final class ComposerState: ObservableObject {
        @Published var pending = false
        @Published var running = false
        var stops = 0
        var sent: [String] = []
    }

    private struct Harness: View {
        @ObservedObject var workspace: FluxStore<WorkspaceFeature>
        @ObservedObject var state: ComposerState
        @State private var draft = ""

        var body: some View {
            var presentation = SessionPresentation()
            presentation.draft = draft
            presentation.canEditMessage = !state.pending
            presentation.canSend = !state.pending && !state.running
            presentation.canStop = state.running
            return SessionScreen(presentation: presentation,
                onDraftChanged: { draft = $0 },
                onConnect: {}, onDisconnect: {},
                onSend: { text in state.sent.append(text); state.pending = true },
                onStop: { state.stops += 1 }, showsHeader: false)
        }
    }

    private let workspace: FluxStore<WorkspaceFeature>
    private let state: ComposerState
    private let app: MacTextInputHarness

    init() {
        let workspace = FluxStore<WorkspaceFeature>(state: .init())
        let tab = OpenSession(identity: .init(scope: "scope", sessionPath: nil,
            runtimeId: "runtime", projectPath: "/repo"), title: "Session")
        workspace.dispatch(.opened(workspace.state.generation, tab))
        let state = ComposerState()
        self.workspace = workspace
        self.state = state
        app = MacTextInputHarness(Harness(workspace: workspace, state: state), width: 760)
    }

    @Test(arguments: [CGFloat(360), CGFloat(760), CGFloat(1708)])
    func theEditorFillsItsVisibleInputArea(width: CGFloat) async throws {
        let widthApp = MacTextInputHarness(Harness(workspace: workspace, state: state), width: width)
        try await widthApp.settle()
        try widthApp.wholeWidthShouldAcceptClicks()
    }

    @Test func typingRemainsLocalInsteadOfUpdatingWorkspaceState() async throws {
        let before = workspace.state
        try await app.type("hello world")
        try app.textShouldBe("hello world")
        #expect(workspace.state == before)
    }


    @Test func aLockedComposerRetainsFocusWithoutChangingItsDraft() async throws {
        state.pending = true
        try await app.type("ignored")
        try app.editingShouldBeEnabled(true)
        try app.composerShouldBeFocused()
        #expect(workspace.state.selectedSession != nil)
        try app.textShouldBe("")
    }

    @Test func autoFocusedComposerRejectsEditsWhenLocked() async throws {
        let focusedApp = MacTextInputHarness(Harness(workspace: workspace, state: state))
        try await focusedApp.settle()
        try focusedApp.composerShouldBeFocused()

        state.pending = true
        try await focusedApp.type("ignored")

        try focusedApp.textShouldBe("")
        try focusedApp.composerShouldBeFocused()
    }

    @Test func returnSubmitsExactTextButRepeatDoesNotSubmit() async throws {
        try await app.type(" hello\nworld ")
        try await app.pressReturn(repeating: true)
        #expect(state.sent.isEmpty)
        try await app.pressReturn()
        #expect(state.sent == [" hello\nworld "])
        try app.textShouldBe(" hello\nworld ")
    }

    @Test func shiftReturnReplacesTheSelectionWithoutSending() async throws {
        try await app.type("hello world")
        try await app.select(NSRange(location: 5, length: 1))
        try await app.pressReturn(shift: true)
        #expect(state.sent.isEmpty)
        try app.textShouldBe("hello\nworld")
        try await app.undo()
        try app.textShouldBe("hello world")
        try await app.redo()
        try app.textShouldBe("hello\nworld")
    }

    @Test func whitespaceReturnNeverSends() async throws {
        try await app.type(" \n ")
        try await app.pressReturn()
        #expect(state.sent.isEmpty)
        try app.textShouldBe(" \n ")
    }

    @Test(arguments: [false, true])
    func returnConfirmsMarkedTextWithoutSending(shift: Bool) async throws {
        try await app.beginComposition("漢")
        try await app.pressReturn(shift: shift)
        #expect(state.sent.isEmpty)
        // Synthetic marked text checks command suppression, not a real input-method session.
        // Candidate preservation/confirmation remains an explicit manual acceptance check.
    }

    @Test func escapeStillWorksAfterSubmissionLocksTheComposer() async throws {
        try await app.type("hello")
        try await app.pressReturn()
        try app.editingShouldBeEnabled(true)
        try app.composerShouldBeFocused()
        try await app.pressEscape()
        #expect(state.stops == 0) // Admission is still pending; Stop is not available yet.
        state.pending = false
        state.running = true
        try await app.settle()
        try app.composerShouldBeFocused()
        try await app.pressEscape()
        #expect(state.stops == 1)
        state.running = false
        try await app.settle()
        try app.composerShouldBeFocused()
    }

    @Test func runningSessionKeepsComposerEditableForTheNextDraft() async throws {
        state.running = true

        try await app.type("Next prompt")

        try app.textShouldBe("Next prompt")
        try app.editingShouldBeEnabled(true)
        try await app.pressReturn()
        // The draft is editable while running, but cannot be sent until idle.
        try app.textShouldBe("Next prompt")
    }

    @Test func escapeStopsOnlyOnTheFirstUnmodifiedPress() async throws {
        state.running = true
        try await app.type("hello")
        try await app.pressEscape(repeating: true)
        try await app.pressEscape(shift: true)
        #expect(state.stops == 0)
        try await app.pressEscape()
        #expect(state.stops == 1)
    }
}
}
#endif
