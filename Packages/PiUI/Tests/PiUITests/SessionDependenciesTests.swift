import FactoryKit
import Flux
import Foundation
import PiSDK
import Testing
@testable import PiUI

/// Container wiring: one scope owns one workspace store, one conversation store, one settings
/// store and the single transport they share.
@MainActor
struct SessionDependenciesTests {
    @Test func storesAndTransportAreCachedWithinOneScopeOnly() {
        let first = Container()
        let second = Container()
        first.endpointSettingsService.register { @MainActor in MemorySettings() }
        second.endpointSettingsService.register { @MainActor in MemorySettings() }
        #expect(first.workspaceStore() === first.workspaceStore())
        #expect(first.sessionStore() === first.sessionStore())
        #expect(first.sessionTransport() === first.sessionTransport())
        #expect(first.settingsModal() === first.settingsModal())
        #expect(first.workspaceStore() !== second.workspaceStore())
        #expect(first.sessionStore() !== second.sessionStore())
        #expect(first.sessionTransport() !== second.sessionTransport())
        #expect(first.settingsModal() !== second.settingsModal())
        #expect(first.workspaceStore().state.connection == .disconnected)
    }

    @Test func savedSettingsReachTheWorkspaceConnectionWithoutLeakingScopes() async throws {
        let first = Container()
        let second = Container()
        first.endpointSettingsService.register { @MainActor in MemorySettings() }
        second.endpointSettingsService.register { @MainActor in MemorySettings() }
        let connection = DependencyConnectionStub()
        let log = EndpointLog()
        first.makeSessionConnection.register { [log] in
            { url in log.values.withLock { $0.append(url.absoluteString) }; return connection }
        }
        let workspace = first.workspaceStore()
        let settings = first.settingsStore()
        settings.dispatch(.opened)
        // Opening presents through the router before editing; the flow reset is async.
        try await waitUntil { first.settingsModal().presentation != nil }
        settings.dispatch(.draftChanged("wss://saved.example/custom"))
        settings.dispatch(.saveTapped)
        try await waitUntil { settings.state.savedEndpoint == "wss://saved.example/custom" }
        #expect(second.settingsStore().state.savedEndpoint == ServerEndpoint.defaultValue)
        workspace.dispatch(.connectRequested(takingControl: true))
        try await waitUntil { await connection.connectCount == 1 }
        #expect(log.values.withLock { $0 } == ["wss://saved.example/custom"])
        workspace.dispatch(.disconnectRequested())
        try await waitUntil { workspace.state.connection == .disconnected }
        #expect(await connection.closed)
    }

    @Test func theWorkspacePublishesItsConnectionForTheConversation() async throws {
        let container = Container()
        container.endpointSettingsService.register { @MainActor in MemorySettings() }
        let connection = DependencyConnectionStub()
        container.makeSessionConnection.register { { _ in connection } }
        let workspace = container.workspaceStore()
        let transport = container.sessionTransport()
        #expect(transport.connection == nil)
        workspace.dispatch(.connectRequested(takingControl: true))
        try await waitUntil {
            guard transport.connection != nil else { return false }
            return await connection.connectCount == 1
        }
        workspace.dispatch(.disconnectRequested())
        try await waitUntil { transport.connection == nil }
        // The conversation store never owns the connection and stays untouched by it.
        #expect(container.sessionStore().state.connection == .disconnected)
    }

    @Test func anotherScopeGetsItsOwnEndpointDefault() {
        let container = Container()
        container.endpointSettingsService.register { @MainActor in MemorySettings() }
        #expect(container.settingsStore().state.savedEndpoint == ServerEndpoint.defaultValue)
    }

    private func waitUntil(sourceLocation: SourceLocation = #_sourceLocation,
                           _ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Container effect did not settle", sourceLocation: sourceLocation)
    }
}

@MainActor
private final class MemorySettings: EndpointSettingsService {
    var value: String?
    func load() -> String? { value }
    func save(_ endpoint: String) throws { value = endpoint }
}

private actor DependencyConnectionStub: PiSessionConnection {
    var connectCount = 0
    var closed = false
    func connect(takingControl: Bool) async throws {
        guard takingControl else { throw PiError.invalidState }
        connectCount += 1
    }
    func catalogues() async -> AsyncStream<PiCatalogue> { AsyncStream { $0.finish() } }
    func sessionEvents() async -> AsyncStream<PiSessionEvent> { AsyncStream { $0.finish() } }
    func attachSession(sessionId: String) async throws -> DemoSession { throw PiError.invalidState }
    func openSession(sessionPath: String) async throws -> DemoSession { throw PiError.invalidState }
    func createSession(projectPath: String) async throws -> DemoSession { throw PiError.invalidState }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession { throw PiError.invalidState }
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func projections() async -> AsyncStream<DemoSessionProjection> { AsyncStream { $0.finish() } }
    func send(_ text: String) async throws {}
    func stop() async throws {}
    func disconnect() async { closed = true }
}
