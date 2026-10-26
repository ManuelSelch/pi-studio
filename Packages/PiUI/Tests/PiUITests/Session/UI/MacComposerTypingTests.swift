#if os(macOS)
import Flux
import Foundation
import SwiftUI
import Testing
@testable import PiUI

extension MacComposerTests {
@MainActor
struct MacComposerTypingTests {
    private struct Harness: View {
        @ObservedObject var workspace: FluxStore<WorkspaceFeature>
        let canEdit: Bool
        let onSend: @MainActor (String) -> Void
        let onStop: @MainActor () -> Void

        var body: some View {
            var presentation = SessionPresentation()
            presentation.draft = workspace.state.draft
            presentation.canEditMessage = canEdit
            presentation.canSend = canEdit
            presentation.canStop = true
            return SessionScreen(presentation: presentation,
                onDraftChanged: { workspace.dispatch(.draftChanged($0)) },
                onConnect: {}, onDisconnect: {}, onSend: onSend, onStop: onStop, showsHeader: false)
        }
    }

    private func fixture(canEdit: Bool = true, width: CGFloat = 760,
                         onSend: @escaping @MainActor (String) -> Void = { _ in },
                         onStop: @escaping @MainActor () -> Void = {}) -> (FluxStore<WorkspaceFeature>, MacComposerDriver) {
        let workspace = FluxStore<WorkspaceFeature>(state: .init())
        let tab = OpenSession(identity: .init(scope: "scope", sessionPath: nil,
            runtimeId: "runtime", projectPath: "/repo"), title: "Session")
        workspace.dispatch(.opened(workspace.state.generation, tab))
        return (workspace, MacComposerDriver(Harness(workspace: workspace, canEdit: canEdit, onSend: onSend, onStop: onStop), width: width))
    }

    @Test(arguments: [CGFloat(360), CGFloat(760), CGFloat(1708)])
    func theEditorFillsItsVisibleInputArea(width: CGFloat) async throws {
        let (_, app) = fixture(width: width)
        try await app.settle()
        try app.wholeWidthShouldAcceptClicks()
    }

    @Test func typingReachesTheStoreBackedDraftAndSurvivesRendering() async throws {
        let (workspace, app) = fixture()
        try await app.type("hello")
        #expect(workspace.state.draft == "hello")
        try await app.type(" world")
        #expect(workspace.state.draft == "hello world")
        try app.textShouldBe("hello world")
    }

    @Test func anExternalDraftChangeIsAdopted() async throws {
        let (workspace, app) = fixture()
        try await app.type("draft")
        workspace.dispatch(.draftChanged("other tab"))
        try await app.settle()
        try app.textShouldBe("other tab")
        workspace.dispatch(.draftChanged(""))
        try await app.settle()
        try app.textShouldBe("")
    }

    @Test func aLockedComposerDisablesEditing() async throws {
        let (workspace, app) = fixture(canEdit: false)
        try await app.settle()
        try app.editingShouldBeEnabled(false)
        #expect(workspace.state.draft.isEmpty)
    }

    @Test func returnSubmitsExactTextButRepeatDoesNotSubmit() async throws {
        var sent: [String] = []
        let (_, app) = fixture(onSend: { sent.append($0) })
        try await app.type(" hello\nworld ")
        try await app.pressReturn(repeating: true)
        #expect(sent.isEmpty)
        try await app.pressReturn()
        #expect(sent == [" hello\nworld "])
        try app.textShouldBe(" hello\nworld ")
    }

    @Test func shiftReturnReplacesTheSelectionWithoutSending() async throws {
        var sent: [String] = []
        let (workspace, app) = fixture(onSend: { sent.append($0) })
        try await app.type("hello world")
        try await app.select(NSRange(location: 5, length: 1))
        try await app.pressReturn(shift: true)
        #expect(sent.isEmpty)
        #expect(workspace.state.draft == "hello\nworld")
        try app.textShouldBe("hello\nworld")
        try await app.undo()
        try app.textShouldBe("hello world")
        try await app.redo()
        try app.textShouldBe("hello\nworld")
    }

    @Test func whitespaceReturnNeverSends() async throws {
        var sent: [String] = []
        let (_, app) = fixture(onSend: { sent.append($0) })
        try await app.type(" \n ")
        try await app.pressReturn()
        #expect(sent.isEmpty)
        try app.textShouldBe(" \n ")
    }

    @Test(arguments: [false, true])
    func returnConfirmsMarkedTextWithoutSending(shift: Bool) async throws {
        var sent: [String] = []
        let (_, app) = fixture(onSend: { sent.append($0) })
        try await app.beginComposition("漢")
        try await app.pressReturn(shift: shift)
        #expect(sent.isEmpty)
        // Synthetic marked text checks command suppression, not a real input-method session.
        // Candidate preservation/confirmation remains an explicit manual acceptance check.
    }

    @MainActor private final class RunState: ObservableObject {
        @Published var pending = false
        @Published var running = false
    }

    private struct RunHarness: View {
        @State private var draft = ""
        @ObservedObject var run: RunState
        let onStop: @MainActor () -> Void
        var body: some View {
            var presentation = SessionPresentation()
            presentation.draft = draft
            presentation.canEditMessage = !run.pending && !run.running
            presentation.canSend = !run.pending && !run.running
            presentation.canStop = run.running
            return SessionScreen(presentation: presentation, onDraftChanged: { draft = $0 },
                onConnect: {}, onDisconnect: {}, onSend: { _ in run.pending = true }, onStop: onStop,
                showsHeader: false)
        }
    }

    @Test func escapeStillWorksAfterSubmissionDisablesTheField() async throws {
        var stops = 0
        let run = RunState()
        let app = MacComposerDriver(RunHarness(run: run, onStop: { stops += 1 }))
        try await app.type("hello")
        try await app.pressReturn()
        try app.editingShouldBeEnabled(false)
        try await app.pressEscape()
        #expect(stops == 0) // Admission is still pending; Stop is not available yet.
        run.pending = false
        run.running = true
        try await app.settle()
        try await app.pressEscape()
        #expect(stops == 1)
    }

    @Test func escapeStopsOnlyOnTheFirstUnmodifiedPress() async throws {
        var stops = 0
        let (_, app) = fixture(onStop: { stops += 1 })
        try await app.type("hello")
        try await app.pressEscape(repeating: true)
        try await app.pressEscape(shift: true)
        #expect(stops == 0)
        try await app.pressEscape()
        #expect(stops == 1)
    }
}
}
#endif
