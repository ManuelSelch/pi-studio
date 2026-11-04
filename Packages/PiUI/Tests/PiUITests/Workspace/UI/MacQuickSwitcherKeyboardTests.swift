#if os(macOS)
import SwiftUI
import Testing
@testable import PiUI

extension MacComposerTests {
@MainActor
struct MacQuickSwitcherKeyboardTests {
    @MainActor private final class State: ObservableObject {
        @Published var query = "studio"
    }

    private struct Harness: View {
        @ObservedObject var state: State
        var body: some View {
            var presentation = WorkspacePresentation()
            presentation.quickSwitcherOpen = true
            presentation.quickSwitcherQuery = state.query
            var actions = WorkspaceActions(open: { _, _ in }, create: { _ in }, connection: {}, settings: {},
                back: {}, draftChanged: { _ in }, send: { _ in }, stop: {}, selectTab: { _ in },
                closeTab: { _ in }, followTailChanged: { _ in }, scrollAnchorChanged: { _ in })
            actions.quickSwitcherQueryChanged = { state.query = $0 }
            return QuickSwitcherContent(presentation: presentation, actions: actions)
        }
    }

    private let state: State
    private let app: MacTextInputHarness

    init() {
        let state = State()
        self.state = state
        app = MacTextInputHarness(Harness(state: state))
    }

    @Test func tabAndShiftTabCycleInOppositeDirections() async throws {
        try await app.pressTab()
        #expect(state.query == "#studio")
        try await app.pressTab(shift: true)
        #expect(state.query == "studio")
        try await app.pressTab(shift: true)
        #expect(state.query == "/studio")
        try await app.pressTab()
        #expect(state.query == "studio")
    }
}
}
#endif
