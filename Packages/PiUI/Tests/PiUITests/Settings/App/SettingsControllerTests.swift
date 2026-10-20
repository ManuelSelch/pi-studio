import Foundation
import Testing
@testable import PiUI

@MainActor
struct SettingsControllerTests {
    @Test func missingOrInvalidStoredEndpointUsesDefault() {
        for value in [nil, "", "https://example.com", "ws://"] as [String?] {
            let controller = SettingsController(service: MemoryEndpointSettings(value))
            #expect(controller.endpoint.absoluteString == "ws://127.0.0.1:8787/ws")
        }
    }

    @Test func savesTrimmedEndpointAndLoadsItInNewController() {
        let service = MemoryEndpointSettings()
        let controller = SettingsController(service: service)
        controller.open()
        controller.setDraft("  wss://example.com:9443/custom?mode=demo \n")
        controller.save()
        #expect(service.value == "wss://example.com:9443/custom?mode=demo")
        #expect(!controller.store.state.isPresented)
        #expect(SettingsController(service: service).endpoint == controller.endpoint)
    }

    @Test func invalidInputDoesNotSaveAndCancelDiscardsDraft() {
        let service = MemoryEndpointSettings()
        let controller = SettingsController(service: service)
        controller.open()
        controller.setDraft("http://example.com")
        controller.save()
        #expect(controller.store.state.error != nil)
        #expect(controller.store.state.isPresented)
        #expect(service.value == nil)
        controller.cancel()
        controller.open()
        #expect(controller.store.state.draft == controller.endpoint.absoluteString)
        #expect(controller.store.state.error == nil)
    }

    @Test func saveFailureRetainsDraftAndEffectiveEndpointForRetry() {
        let service = MemoryEndpointSettings()
        let controller = SettingsController(service: service)
        let original = controller.endpoint
        controller.open()
        controller.setDraft("ws://example.com/ws")
        service.rejectSave = true
        controller.save()
        #expect(controller.endpoint == original)
        #expect(controller.store.state.draft == "ws://example.com/ws")
        #expect(controller.store.state.error != nil)
        #expect(controller.store.state.isPresented)
        service.rejectSave = false
        controller.save()
        #expect(controller.endpoint.absoluteString == "ws://example.com/ws")
        #expect(!controller.store.state.isPresented)
    }
}

@MainActor
final class MemoryEndpointSettings: EndpointSettingsService {
    var value: String?
    var rejectSave = false
    init(_ value: String? = nil) { self.value = value }
    func load() -> String? { value }
    func save(_ endpoint: String) throws {
        if rejectSave { throw SaveError() }
        value = endpoint
    }
    private struct SaveError: LocalizedError {
        var errorDescription: String? { "Could not save endpoint." }
    }
}
