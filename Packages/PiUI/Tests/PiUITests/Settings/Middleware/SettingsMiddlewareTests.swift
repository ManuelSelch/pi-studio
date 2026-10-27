import FactoryKit
import Flux
import Foundation
import Router
import Testing
@testable import PiUI

@MainActor
struct SettingsMiddlewareTests {
    private let service: MemoryEndpointSettings
    private let scope: Container
    private let store: FluxStore<SettingsFeature>
    private let modal: ModalRouter<AppRoute>

    init() {
        let service = MemoryEndpointSettings()
        let scope = Self.makeScope(service)

        self.service = service
        self.scope = scope
        self.store = scope.settingsStore()
        self.modal = scope.settingsModal()
    }

    @Test func missingOrInvalidStoredEndpointUsesDefault() {
        for value in [nil, "", "https://example.com", "ws://"] as [String?] {
            let scope = Self.makeScope(MemoryEndpointSettings(value))

            #expect(scope.settingsStore().state.savedEndpoint == "ws://127.0.0.1:8787/ws")
        }
    }

    @Test func openingPresentsThroughTheRouterAndDuplicateOpenPreservesTheFlow() async throws {
        store.dispatch(.opened)
        try await waitUntil { modal.presentation?.stack.root == .settings }
        let id = try #require(modal.presentation).id

        #expect(modal.presentation?.canDismiss == true)

        store.dispatch(.draftChanged("ws://draft.test/ws"))
        store.dispatch(.opened)
        try await Task.sleep(for: .milliseconds(30))

        #expect(modal.presentation?.id == id)
        #expect(store.state.draft == "ws://draft.test/ws")
    }

    @Test func savesTrimmedEndpointAndDismissesTheFlow() async throws {
        store.dispatch(.opened)
        try await waitUntil { modal.presentation != nil }

        store.dispatch(.draftChanged("  wss://example.com:9443/custom?mode=demo \n"))
        store.dispatch(.saveTapped)
        try await waitUntil {
            store.state.savedEndpoint == "wss://example.com:9443/custom?mode=demo" && modal.presentation == nil
        }

        #expect(service.value == "wss://example.com:9443/custom?mode=demo")
        #expect(!store.state.isSaving)
        #expect(Self.makeScope(service).settingsStore().state.savedEndpoint == store.state.savedEndpoint)
    }

    @Test func cancelPreservesEditingStateUntilReopening() async throws {
        store.dispatch(.opened)
        try await waitUntil { modal.presentation != nil }

        store.dispatch(.draftChanged("http://example.com"))
        store.dispatch(.saveTapped)
        try await waitUntil { store.state.error != nil && !store.state.isSaving }

        #expect(modal.presentation != nil)
        #expect(service.value == nil)

        store.dispatch(.cancelTapped)
        try await waitUntil { modal.presentation == nil }

        #expect(store.state.draft == "http://example.com")
        #expect(store.state.error != nil)
        #expect(service.value == nil)

        store.dispatch(.opened)
        try await waitUntil { modal.presentation != nil && store.state.error == nil }

        #expect(store.state.draft == store.state.savedEndpoint)
        #expect(store.state.error == nil)
    }

    @Test func nativeDismissalNeedsNoCleanupBeforeReopening() async throws {
        store.dispatch(.opened)
        try await waitUntil { modal.presentation != nil }

        store.dispatch(.draftChanged("invalid"))
        store.dispatch(.saveTapped)
        try await waitUntil { store.state.error != nil && modal.presentation?.canDismiss == true }

        let flow = try #require(modal.presentation)

        #expect(modal.dismiss(id: flow.id))

        #expect(store.state.draft == "invalid")
        #expect(store.state.error != nil)
        #expect(service.value == nil)

        store.dispatch(.opened)
        try await waitUntil { modal.presentation != nil && store.state.error == nil }

        #expect(modal.presentation?.id != flow.id)
        #expect(store.state.draft == store.state.savedEndpoint)
    }

    @Test func saveFailureRetainsDraftAndEffectiveEndpointForRetry() async throws {
        let original = store.state.savedEndpoint

        store.dispatch(.opened)
        try await waitUntil { modal.presentation != nil }

        store.dispatch(.draftChanged("ws://example.com/ws"))
        service.rejectSave = true
        store.dispatch(.saveTapped)
        try await waitUntil { store.state.error != nil && modal.presentation?.canDismiss == true }

        #expect(store.state.savedEndpoint == original)
        #expect(store.state.draft == "ws://example.com/ws")
        #expect(modal.presentation != nil)

        service.rejectSave = false
        store.dispatch(.saveTapped)
        try await waitUntil { store.state.savedEndpoint == "ws://example.com/ws" && modal.presentation == nil }
    }

    @Test func saveOutsidePresentationAbandonsWithoutPersisting() async throws {
        store.dispatch(.saveTapped)
        try await waitUntil { !store.state.isSaving && store.state.error == nil }

        #expect(service.value == nil)
    }

    @Test func theSavingGuardIsSetWhilePersisting() async throws {
        service.canDismissProbe = { [modal] in modal.presentation?.canDismiss }

        store.dispatch(.opened)
        try await waitUntil { modal.presentation != nil }

        store.dispatch(.draftChanged("wss://example.com/ws"))
        store.dispatch(.saveTapped)
        try await waitUntil { service.saveCount == 1 }

        #expect(service.observedCanDismiss == false)

        store.dispatch(.cancelTapped)
        try await waitUntil { modal.presentation == nil }
    }

    @Test func duplicateSaveAndDismissalCannotInterruptPendingSave() async throws {
        store.dispatch(.opened)
        try await waitUntil { modal.presentation != nil }

        store.dispatch(.draftChanged("wss://example.com/ws"))
        store.dispatch(.saveTapped)
        store.dispatch(.saveTapped)
        store.dispatch(.cancelTapped)
        store.dispatch(.opened)
        store.dispatch(.draftChanged("ignored"))
        try await waitUntil { modal.presentation == nil }

        #expect(service.value == "wss://example.com/ws")
        #expect(service.saveCount == 1)
    }

    private static func makeScope(_ service: MemoryEndpointSettings) -> Container {
        let scope = Container()
        scope.endpointSettingsService.register { service }
        return scope
    }

    private func waitUntil(sourceLocation: SourceLocation = #_sourceLocation,
                           _ condition: @escaping @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(1))
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Settings effect did not settle", sourceLocation: sourceLocation)
    }
}

@MainActor
final class MemoryEndpointSettings: EndpointSettingsService {
    var value: String?
    var rejectSave = false
    var saveCount = 0
    var canDismissProbe: (() -> Bool?)?
    var observedCanDismiss: Bool?

    init(_ value: String? = nil) { self.value = value }

    func load() -> String? { value }

    func save(_ endpoint: String) throws {
        saveCount += 1
        observedCanDismiss = canDismissProbe?()
        if rejectSave { throw SaveError() }
        value = endpoint
    }

    private struct SaveError: LocalizedError {
        var errorDescription: String? { "Could not save endpoint." }
    }
}
