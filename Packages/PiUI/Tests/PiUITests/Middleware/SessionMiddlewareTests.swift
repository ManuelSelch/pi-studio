import Flux
import FluxTestStore
import Foundation
import PiSDK
import Testing
@testable import PiUI

@MainActor
struct SessionMiddlewareTests {
    @Test func connectIsReservedSynchronouslyAndDuplicatesAreIgnored() async {
        let client = MiddlewareConnectionStub()
        let configuration = SessionConfiguration.development
        let middleware = SessionMiddleware(configuration: configuration, makeConnection: { _ in client })
        let store = TestStore<SessionFeature>(state: .init(), middlewares: [middleware])
        defer { store.tearDown() }
        let token = UUID()
        store.dispatch(.connectRequested(token, takingControl: true)) {
            $0.generation = token; $0.connection = .connecting
        }
        store.dispatch(.connectRequested(takingControl: true)) { _ in }
        let session = DemoSession(sessionId: "middleware", projectPath: configuration.projectPath)
        await store.receive([.connectionEndpointSelected(token, configuration.endpoint), .connected(token, session)]) {
            $0.connectionEndpoint = configuration.endpoint
            $0.connection = .ready(session)
        }
        await store.finish()
        #expect(await client.connectCount == 1)
        let disconnected = UUID()
        store.dispatch(.disconnectRequested(disconnected)) {
            $0.generation = disconnected; $0.connection = .disconnected; $0.isDisconnecting = true
        }
        await store.receive(.disconnectFinished(disconnected)) { $0.isDisconnecting = false }
        await store.finish()
        #expect(await client.closed)
    }

    @Test func disconnectBeforeScheduledConnectPreventsAnySDKCall() async {
        let client = MiddlewareConnectionStub()
        let token = UUID()
        let testStore = TestStore<SessionFeature>(state: .init(), middlewares: [
            SessionMiddleware(makeConnection: { _ in client })
        ])
        defer { testStore.tearDown() }
        testStore.dispatch(.connectRequested(token, takingControl: true)) {
            $0.generation = token; $0.connection = .connecting
        }
        let disconnected = UUID()
        testStore.dispatch(.disconnectRequested(disconnected)) {
            $0.generation = disconnected; $0.connection = .disconnected; $0.isDisconnecting = true
            $0.actionError = "Disconnected during setup. A demo runtime may have been created on the server."
        }
        testStore.dispatch(.disconnectRequested()) { _ in }
        testStore.dispatch(.connectRequested(takingControl: true)) { _ in }
        await testStore.receive(.disconnectFinished(disconnected)) { $0.isDisconnecting = false }
        await testStore.finish()
        #expect(await client.connectCount == 0)
    }

    @Test(arguments: [false, true])
    func disconnectInvalidatesQueuedMutation(stop: Bool) async {
        let client = MiddlewareConnectionStub()
        let configuration = SessionConfiguration.development
        let store = TestStore<SessionFeature>(state: .init(), middlewares: [
            SessionMiddleware(makeConnection: { _ in client })
        ])
        defer { store.tearDown() }
        let token = UUID()
        store.dispatch(.connectRequested(token, takingControl: true)) {
            $0.generation = token; $0.connection = .connecting
        }
        let session = DemoSession(sessionId: "middleware", projectPath: configuration.projectPath)
        await store.receive([.connectionEndpointSelected(token, configuration.endpoint), .connected(token, session)]) {
            $0.connectionEndpoint = configuration.endpoint; $0.connection = .ready(session)
        }
        await store.finish()
        let projection = DemoSessionProjection(session: session, status: stop ? .running : .idle)
        store.dispatch(.projectionChanged(token, projection)) { $0.projection = projection }
        let request = UUID()
        if stop {
            store.dispatch(.stopRequested(request)) { $0.isStopping = true; $0.stopRequest = request }
        } else {
            store.dispatch(.sendRequested(request, text: "Never send")) { $0.isSending = true; $0.sendRequest = request }
        }
        let disconnected = UUID()
        store.dispatch(.disconnectRequested(disconnected)) {
            $0.generation = disconnected; $0.connection = .disconnected; $0.isDisconnecting = true
            $0.isSending = false; $0.isStopping = false; $0.sendRequest = nil; $0.stopRequest = nil
            $0.actionError = "Request outcome unknown after disconnect. Server work may continue; nothing will be resent automatically."
        }
        await store.receive(.disconnectFinished(disconnected)) { $0.isDisconnecting = false }
        await store.finish()
        #expect(await client.sendCount == 0)
        #expect(await client.stopCount == 0)
    }

    @Test func sendRequestReservesSnapshotAndBlocksDuplicateAdmission() async {
        let token = UUID()
        let session = DemoSession(sessionId: "middleware", projectPath: "/tmp/demo")
        var initial = SessionFeature.State()
        initial.generation = token
        initial.connection = .ready(session)
        initial.projection = .init(session: session)
        let store = TestStore<SessionFeature>(state: initial)
        defer { store.tearDown() }
        let request = UUID()
        store.dispatch(.sendRequested(request, text: "First")) {
            $0.isSending = true; $0.sendRequest = request
        }
        store.dispatch(.sendRequested(text: "Next")) { _ in }
        store.dispatch(.sendFinished(token, submitted: "First", error: nil)) {
            $0.isSending = false; $0.sendRequest = nil; $0.clearDraftMatching = "First"
        }
        await store.finish()
    }
}

private actor MiddlewareConnectionStub: PiDemoConnection {
    var connectCount = 0
    var closed = false
    var sendCount = 0
    var stopCount = 0
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession {
        connectCount += 1
        return .init(sessionId: "middleware", projectPath: projectPath)
    }
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func projections() async -> AsyncStream<DemoSessionProjection> { AsyncStream { $0.finish() } }
    func send(_ text: String) async throws { sendCount += 1 }
    func stop() async throws { stopCount += 1 }
    func disconnect() async { closed = true }
}
