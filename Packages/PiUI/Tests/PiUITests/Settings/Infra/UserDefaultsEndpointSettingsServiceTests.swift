import Foundation
import Testing
@testable import PiUI

@MainActor
struct UserDefaultsEndpointSettingsServiceTests {
    @Test func persistsAcrossAdaptersAndRejectsInvalidWrites() throws {
        let suite = "PiStudio.Tests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = UserDefaultsEndpointSettingsService(defaults: defaults)
        #expect(service.load() == nil)
        try service.save("  wss://example.com:9443/custom?mode=test  ")
        let secondDefaults = try #require(UserDefaults(suiteName: suite))
        let second = UserDefaultsEndpointSettingsService(defaults: secondDefaults)
        #expect(second.load() == "wss://example.com:9443/custom?mode=test")
        #expect(throws: (any Error).self) { try service.save("http://example.com") }
        #expect(second.load() == "wss://example.com:9443/custom?mode=test")
    }

    @Test func suitesRemainIsolated() throws {
        let firstName = "PiStudio.Tests." + UUID().uuidString
        let secondName = "PiStudio.Tests." + UUID().uuidString
        let first = try #require(UserDefaults(suiteName: firstName))
        let second = try #require(UserDefaults(suiteName: secondName))
        defer { first.removePersistentDomain(forName: firstName); second.removePersistentDomain(forName: secondName) }
        try UserDefaultsEndpointSettingsService(defaults: first).save("ws://first/ws")
        #expect(UserDefaultsEndpointSettingsService(defaults: second).load() == nil)
    }
}
