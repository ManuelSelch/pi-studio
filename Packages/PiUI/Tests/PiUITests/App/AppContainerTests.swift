import Flux
import Foundation
import Router
import Testing
@testable import PiUI

@MainActor
struct AppContainerTests {
    @Test func openingTwicePreservesTheActiveFlowAndDraft() throws {
        let app = AppRoutingDriver()
        app.openSettings()
        let id = try app.presentationID()
        app.editEndpoint("ws://draft.test/ws")
        app.openSettings()
        app.shouldPresent(id: id)
        app.draftShouldBe("ws://draft.test/ws")
    }

    @Test func interactiveDismissalCancelsAndReopeningResetsTheDraft() throws {
        let app = AppRoutingDriver()
        app.openSettings()
        let previous = try app.presentationID()
        app.editEndpoint("ws://discard.test/ws")
        app.dismissInteractively()
        app.shouldBeClosed()
        app.openSettings()
        app.draftShouldBe("ws://saved.test/ws")
        #expect(try app.presentationID() != previous)
    }

    @Test func savingBlocksDismissalAndFailureKeepsTheFlowOpen() throws {
        let app = AppRoutingDriver()
        app.openSettings()
        let id = try app.presentationID()
        app.editEndpoint("ws://next.test/ws")
        app.beginSaving()
        app.dismissInteractively()
        app.shouldPresent(id: id)
        app.failSaving()
        app.shouldPresent(id: id)
        app.draftShouldBe("ws://next.test/ws")
        app.dismissInteractively()
        app.shouldBeClosed()
    }

    @Test func successfulSaveDismissesEvenAfterTheGuardWasSet() {
        let app = AppRoutingDriver()
        app.openSettings()
        app.beginSaving()
        app.finishSaving()
        app.shouldBeClosed()
        app.openSettings()
        app.draftShouldBe("ws://next.test/ws")
        app.cancel()
        app.shouldBeClosed()
    }

    @Test func closedStateDoesNotCreateAFlow() {
        let app = AppRoutingDriver()
        app.synchronize()
        app.shouldBeClosed()
    }
}

/// Exercises the production state/modal bridge without launching or controlling a Mac app.
/// Native settings UI scenarios separately verify SwiftUI observer wiring.
@MainActor
private final class AppRoutingDriver {
    private let settings = FluxStore<SettingsFeature>(state: .init(endpoint: "ws://saved.test/ws"))
    private let modal = ModalRouter<AppRoute>()

    func synchronize() { AppContainer.synchronizeSettings(settings.state, modal: modal) }
    func openSettings() {
        AppContainer.openSettings(in: settings)
        synchronize()
    }
    func editEndpoint(_ value: String) {
        settings.dispatch(.draftChanged(value))
        synchronize()
    }
    func beginSaving() {
        settings.dispatch(.saveTapped())
        synchronize()
    }
    func failSaving() {
        settings.dispatch(.saveFailed("Cannot save"))
        synchronize()
    }
    func finishSaving() {
        settings.dispatch(.saved("ws://next.test/ws"))
        synchronize()
        AppContainer.settingsDismissed(in: settings, modal: modal)
    }
    func cancel() {
        settings.dispatch(.cancelled)
        synchronize()
        AppContainer.settingsDismissed(in: settings, modal: modal)
    }
    func dismissInteractively() {
        modal.dismiss()
        AppContainer.settingsDismissed(in: settings, modal: modal)
        synchronize()
    }
    func presentationID() throws -> UUID {
        try #require(modal.presentation).id
    }
    func shouldPresent(id: UUID, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(modal.presentation?.id == id, sourceLocation: sourceLocation)
        #expect(modal.presentation?.stack.root == .settings, sourceLocation: sourceLocation)
        #expect(settings.state.isPresented, sourceLocation: sourceLocation)
    }
    func shouldBeClosed(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(modal.presentation == nil, sourceLocation: sourceLocation)
        #expect(!settings.state.isPresented, sourceLocation: sourceLocation)
    }
    func draftShouldBe(_ value: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(settings.state.draft == value, sourceLocation: sourceLocation)
    }
}
