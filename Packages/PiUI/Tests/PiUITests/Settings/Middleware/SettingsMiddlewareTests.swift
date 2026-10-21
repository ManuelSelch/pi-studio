import FactoryKit
import Flux
import Foundation
import Testing
@testable import PiUI

@MainActor
struct SettingsMiddlewareTests {
    @Test func missingOrInvalidStoredEndpointUsesDefault() {
        for value in [nil, "", "https://example.com", "ws://"] as [String?] {
            let scope = makeScope(MemoryEndpointSettings(value))
            #expect(scope.settingsStore().state.savedEndpoint == "ws://127.0.0.1:8787/ws")
        }
    }

    @Test func savesTrimmedEndpointAndLoadsItInNewStore() async throws {
        let service = MemoryEndpointSettings()
        let scope = makeScope(service)
        let store = scope.settingsStore()
        store.dispatch(.opened)
        store.dispatch(.draftChanged("  wss://example.com:9443/custom?mode=demo \n"))
        try await save(store)
        #expect(service.value == "wss://example.com:9443/custom?mode=demo")
        #expect(!store.state.isPresented)
        #expect(makeScope(service).settingsStore().state.savedEndpoint == store.state.savedEndpoint)
    }

    @Test func invalidInputDoesNotSaveAndCancelDiscardsDraft() async throws {
        let service = MemoryEndpointSettings()
        let scope = makeScope(service)
        let store = scope.settingsStore()
        store.dispatch(.opened)
        store.dispatch(.draftChanged("http://example.com"))
        try await save(store)
        #expect(store.state.error != nil)
        #expect(store.state.isPresented)
        #expect(service.value == nil)
        store.dispatch(.cancelled)
        store.dispatch(.opened)
        #expect(store.state.draft == store.state.savedEndpoint)
        #expect(store.state.error == nil)
    }

    @Test func saveFailureRetainsDraftAndEffectiveEndpointForRetry() async throws {
        let service = MemoryEndpointSettings()
        let scope = makeScope(service)
        let store = scope.settingsStore()
        let original = store.state.savedEndpoint
        store.dispatch(.opened)
        store.dispatch(.draftChanged("ws://example.com/ws"))
        service.rejectSave = true
        try await save(store)
        #expect(store.state.savedEndpoint == original)
        #expect(store.state.draft == "ws://example.com/ws")
        #expect(store.state.error != nil)
        #expect(store.state.isPresented)
        service.rejectSave = false
        try await save(store)
        #expect(store.state.savedEndpoint == "ws://example.com/ws")
        #expect(!store.state.isPresented)
    }

    @Test func saveOutsidePresentationDoesNothing() async throws {
        let service = MemoryEndpointSettings()
        let scope = makeScope(service)
        let store = scope.settingsStore()
        try await save(store)
        #expect(service.value == nil)
        #expect(store.state.error == nil)
    }

    @Test func duplicateSaveAndDismissalCannotInterruptPendingSave() async throws {
        let service = MemoryEndpointSettings()
        let scope = makeScope(service)
        let store = scope.settingsStore()
        store.dispatch(.opened)
        store.dispatch(.draftChanged("wss://example.com/ws"))
        store.dispatch(.saveTapped())
        store.dispatch(.saveTapped())
        store.dispatch(.cancelled)
        store.dispatch(.opened)
        store.dispatch(.draftChanged("ignored"))
        #expect(store.state.isPresented)
        #expect(store.state.draft == "wss://example.com/ws")
        try await waitForSave(store)
        #expect(service.value == "wss://example.com/ws")
        #expect(service.saveCount == 1)
    }

    private func makeScope(_ service: MemoryEndpointSettings) -> Container {
        let scope = Container()
        scope.endpointSettingsService.register { service }
        return scope
    }

    private func save(_ store: FluxStore<SettingsFeature>) async throws {
        store.dispatch(.saveTapped())
        try await waitForSave(store)
    }

    private func waitForSave(_ store: FluxStore<SettingsFeature>) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while store.state.isSaving, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(!store.state.isSaving, "Settings save did not settle")
    }
}

@MainActor
final class MemoryEndpointSettings: EndpointSettingsService {
    var value: String?
    var rejectSave = false
    var saveCount = 0
    init(_ value: String? = nil) { self.value = value }
    func load() -> String? { value }
    func save(_ endpoint: String) throws {
        saveCount += 1
        if rejectSave { throw SaveError() }
        value = endpoint
    }
    private struct SaveError: LocalizedError {
        var errorDescription: String? { "Could not save endpoint." }
    }
}
