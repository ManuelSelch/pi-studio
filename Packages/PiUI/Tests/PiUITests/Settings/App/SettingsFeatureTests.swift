import FluxTestStore
import Testing
import Foundation
@testable import PiUI

@MainActor
struct SettingsFeatureTests {
    @Test func openedIsARequestAndFlowStartedResetsTheDraft() async {
        let store = TestStore<SettingsFeature>(state: .init(endpoint: "ws://original/ws"))
        defer { store.tearDown() }
        store.dispatch(.opened) { _ in }
        store.dispatch(.flowStarted) { $0.draft = "ws://original/ws"; $0.error = nil }
        await store.finish()
    }

    @Test func draftCancelFailureAndSaveAreReducedByFlux() async {
        let store = TestStore<SettingsFeature>(state: .init(endpoint: "ws://original/ws"))
        defer { store.tearDown() }
        store.dispatch(.opened) { _ in }
        store.dispatch(.flowStarted) { $0.draft = "ws://original/ws"; $0.error = nil }
        store.dispatch(.draftChanged("invalid")) { $0.draft = "invalid"; $0.error = nil }
        store.dispatch(.saveFailed("Invalid URL")) { $0.isSaving = false; $0.error = "Invalid URL" }
        store.dispatch(.cancelled) { _ in }
        store.dispatch(.opened) { _ in }
        store.dispatch(.flowStarted) { $0.draft = "ws://original/ws"; $0.error = nil }
        store.dispatch(.draftChanged("wss://new/ws")) { $0.draft = "wss://new/ws"; $0.error = nil }
        store.dispatch(.saveTapped) { $0.isSaving = true; $0.error = nil }
        store.dispatch(.draftChanged("ignored")) { _ in }
        store.dispatch(.saveFailed("Try again")) { $0.isSaving = false; $0.error = "Try again" }
        store.dispatch(.saveTapped) { $0.isSaving = true; $0.error = nil }
        store.dispatch(.saved("wss://new/ws")) {
            $0.savedEndpoint = "wss://new/ws"; $0.draft = "wss://new/ws"
            $0.isSaving = false; $0.error = nil
        }
        await store.finish()
    }
}
