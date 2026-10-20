import FluxTestStore
import Testing
@testable import PiUI

@MainActor
struct SettingsFeatureTests {
    @Test func draftCancelFailureAndSaveAreReducedByFlux() async {
        let store = TestStore<SettingsFeature>(state: .init(endpoint: "ws://original/ws"))
        defer { store.tearDown() }
        store.dispatch(.opened) { $0.isPresented = true }
        store.dispatch(.draftChanged("invalid")) { $0.draft = "invalid" }
        store.dispatch(.saveFailed("Invalid URL")) { $0.error = "Invalid URL" }
        store.dispatch(.cancelled) { $0.draft = "ws://original/ws"; $0.error = nil; $0.isPresented = false }
        store.dispatch(.opened) { $0.isPresented = true }
        store.dispatch(.draftChanged("wss://new/ws")) { $0.draft = "wss://new/ws" }
        store.dispatch(.saveStarted) { $0.isSaving = true }
        store.dispatch(.draftChanged("ignored")) { _ in }
        store.dispatch(.saveFailed("Try again")) { $0.isSaving = false; $0.error = "Try again" }
        store.dispatch(.saveStarted) { $0.isSaving = true; $0.error = nil }
        store.dispatch(.saved("wss://new/ws")) {
            $0.isSaving = false; $0.isPresented = false; $0.savedEndpoint = "wss://new/ws"
        }
        await store.finish()
    }
}
