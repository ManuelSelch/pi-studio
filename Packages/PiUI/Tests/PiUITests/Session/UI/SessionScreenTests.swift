#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import PiUI

extension MacComposerTests {
@MainActor
struct SessionScreenTests {
    @MainActor private final class State: ObservableObject {
        @Published var presentation = SessionPresentation()
    }

    private struct Screen: View {
        @ObservedObject var state: State
        var body: some View {
            SessionScreen(presentation: state.presentation, onDraftChanged: { _ in },
                          onConnect: {}, onDisconnect: {},
                          onSend: { _ in }, onStop: {})
        }
    }

    private let state: State
    private let app: MacTextInputHarness

    init() {
        let state = State()
        state.presentation.canEditMessage = true
        self.state = state
        app = MacTextInputHarness(Screen(state: state))
    }

    @Test func closingQuickSwitcherRestoresComposerFocus() async throws {
        try await app.settle()
        try app.composerShouldBeFocused()

        state.presentation.isQuickSwitcherPresented = true
        try await app.settle()
        app.moveFocusAwayFromComposer()
        try app.composerShouldNotBeFocused()
        state.presentation.isQuickSwitcherPresented = false
        try await app.settle()

        try app.composerShouldBeFocused()
    }

    @Test func connectionErrorAppearsAndDisappears() async throws {
        state.presentation.error = "Connection failed"
        try await app.settle()

        #expect(try app.renderedText().contains("Connection failed"))

        state.presentation.error = nil
        try await app.settle()

        #expect(try !app.renderedText().contains("Connection failed"))
    }

    @Test func closingQuickSwitcherDoesNotStealFocusFromAnotherControl() async throws {
        try await app.settle()
        app.moveFocusAwayFromComposer()
        try await app.settle()
        try app.composerShouldNotBeFocused()

        state.presentation.isQuickSwitcherPresented = true
        try await app.settle()
        state.presentation.isQuickSwitcherPresented = false
        try await app.settle()

        try app.composerShouldNotBeFocused()
    }

    @Test func closingQuickSwitcherDoesNotRestoreFocusWhenComposerIsLocked() async throws {
        try await app.settle()
        try app.composerShouldBeFocused()

        state.presentation.isQuickSwitcherPresented = true
        try await app.settle()
        app.moveFocusAwayFromComposer()
        state.presentation.canEditMessage = false
        try await app.settle()
        state.presentation.isQuickSwitcherPresented = false
        try await app.settle()

        try app.composerShouldNotBeFocused()
    }
}
}
#endif
