import FactoryKit
import Flux
import Foundation
import PiSDK
import Testing
@testable import PiUI

@MainActor
struct SessionDependenciesTests {
    @Test func storeIsCachedWithinOneScopeOnly() {
        let first = SessionDependencies()
        let second = SessionDependencies()
        first.endpointSettingsService.register { @MainActor in MemoryEndpointSettings() }
        second.endpointSettingsService.register { @MainActor in MemoryEndpointSettings() }
        #expect(first.sessionStore() === first.sessionStore())
        #expect(first.sessionStore() !== second.sessionStore())
        #expect(first.sessionConfiguration().endpoint == SessionConfiguration.development.endpoint)
        #expect(first.sessionStore().state.connection == .disconnected)
    }

    @Test func savedSettingsReachAlreadyResolvedStoreWithoutLeakingScopes() async throws {
        let first = SessionDependencies()
        let second = SessionDependencies()
        first.endpointSettingsService.register { @MainActor in MemoryEndpointSettings() }
        second.endpointSettingsService.register { @MainActor in MemoryEndpointSettings() }
        let connection = DependencyConnectionStub()
        first.makeConnection.register { { _ in connection } }
        let store = first.sessionStore()
        let settings = first.settingsController()
        #expect(settings === first.settingsController())
        settings.open()
        settings.setDraft("wss://saved.example/custom")
        settings.save()
        #expect(second.settingsController().endpoint == SessionConfiguration.development.endpoint)
        store.dispatch(.connectRequested(takingControl: true))
        try await waitUntil { if case .ready = store.state.connection { true } else { false } }
        #expect(store.state.connectionEndpoint?.absoluteString == "wss://saved.example/custom")
        store.dispatch(.disconnectRequested())
        try await waitUntil { !store.state.isDisconnecting }
        #expect(await connection.closed)
    }

    @Test func registrationsReachMiddlewareWithoutLeakingToAnotherScope() async throws {
        let dependencies = SessionDependencies()
        dependencies.endpointSettingsService.register { @MainActor in MemoryEndpointSettings() }
        let connection = DependencyConnectionStub()
        let configuration = SessionConfiguration(endpoint: URL(string: "ws://127.0.0.1:9999/ws")!, projectPath: "/tmp/injected")
        dependencies.sessionConfiguration.register { configuration }
        dependencies.makeConnection.register { { _ in connection } }
        let store = dependencies.sessionStore()
        #expect(dependencies.sessionConfiguration().endpoint == configuration.endpoint)
        store.dispatch(.connectRequested(takingControl: true))
        try await waitUntil { if case .ready = store.state.connection { true } else { false } }
        #expect(await connection.projectPath == configuration.projectPath)
        #expect(store.state.connection == .ready(.init(sessionId: "injected", projectPath: configuration.projectPath)))
        #expect(store.state.connectionEndpoint == configuration.endpoint)
        store.dispatch(.disconnectRequested())
        try await waitUntil { !store.state.isDisconnecting }
        #expect(await connection.closed)
        let other = SessionDependencies()
        other.endpointSettingsService.register { @MainActor in MemoryEndpointSettings() }
        #expect(other.sessionConfiguration().projectPath == SessionConfiguration.development.projectPath)
    }

    private func waitUntil(sourceLocation: SourceLocation = #_sourceLocation, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
        try #require(condition(), "Session effect did not settle", sourceLocation: sourceLocation)
    }
}

private actor DependencyConnectionStub: PiDemoConnection {
    var projectPath: String?
    var closed = false
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession {
        self.projectPath = projectPath
        return .init(sessionId: "injected", projectPath: projectPath)
    }
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func projections() async -> AsyncStream<DemoSessionProjection> { AsyncStream { $0.finish() } }
    func send(_ text: String) async throws {}
    func stop() async throws {}
    func disconnect() async { closed = true }
}
