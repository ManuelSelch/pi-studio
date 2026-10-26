import FluxTestStore
import Testing
import Foundation
@testable import PiUI

@MainActor
struct SettingsFeatureTests {
    @Test func draftCancelFailureAndSaveAreReducedByFlux() async {
        let first = UUID(), retry = UUID()
        let store = TestStore<SettingsFeature>(state: .init(endpoint: "ws://original/ws"))
        defer { store.tearDown() }
        store.dispatch(.opened) { $0.isPresented = true }
        store.dispatch(.draftChanged("invalid")) { $0.draft = "invalid" }
        store.dispatch(.saveFailed("Invalid URL")) { $0.error = "Invalid URL" }
        store.dispatch(.cancelled) { $0.draft = "ws://original/ws"; $0.error = nil; $0.isPresented = false }
        store.dispatch(.opened) { $0.isPresented = true }
        store.dispatch(.draftChanged("wss://new/ws")) { $0.draft = "wss://new/ws" }
        store.dispatch(.saveTapped(first)) { $0.saveRequest = first }
        store.dispatch(.draftChanged("ignored")) { _ in }
        store.dispatch(.saveFailed("Try again")) { $0.saveRequest = nil; $0.error = "Try again" }
        store.dispatch(.saveTapped(retry)) { $0.saveRequest = retry; $0.error = nil }
        store.dispatch(.saved("wss://new/ws")) {
            $0.saveRequest = nil; $0.isPresented = false; $0.savedEndpoint = "wss://new/ws"
        }
        await store.finish()
    }
}
