import Flux
import Testing
@testable import PiUI

/// Native dismissal is editing cleanup only: it never re-creates Flux/Router visibility sync.
@MainActor
struct AppContainerTests {
    @Test func nativeDismissalDiscardsUnsavedEdits() {
        let store = FluxStore<SettingsFeature>(state: .init(endpoint: "ws://saved.test/ws"))
        store.dispatch(.flowStarted)
        store.dispatch(.draftChanged("ws://discard.test/ws"))
        AppContainer.settingsFlowEnded(in: store)
        #expect(store.state.draft == "ws://saved.test/ws")
        #expect(!store.state.isSaving)
    }

    @Test func nativeDismissalIsIgnoredWhileSavingAndThenCleansUp() {
        let store = FluxStore<SettingsFeature>(state: .init(endpoint: "ws://saved.test/ws"))
        store.dispatch(.flowStarted)
        store.dispatch(.draftChanged("ws://next.test/ws"))
        store.dispatch(.saveTapped)
        AppContainer.settingsFlowEnded(in: store)
        #expect(store.state.isSaving)
        #expect(store.state.draft == "ws://next.test/ws")

        store.dispatch(.saveFailed("Cannot save"))
        AppContainer.settingsFlowEnded(in: store)
        #expect(store.state.draft == "ws://saved.test/ws")
    }
}
