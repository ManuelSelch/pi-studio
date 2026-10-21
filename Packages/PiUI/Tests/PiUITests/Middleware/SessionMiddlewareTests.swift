import FactoryKit
import Flux
import Foundation
import PiSDK
import Testing
@testable import PiUI

/// Middleware-level guarantees for the conversation: one observed runtime, reserved sends,
/// and a transport it only reads.
@MainActor
struct SessionMiddlewareTests {
    @MainActor private final class Fixture {
        let container = Container()
        let connection = SessionConnectionStub()
        let transport = SessionTransport()
        var store: FluxStore<SessionFeature>!
        init() {
            transport.publish(connection)
            container.sessionTransport.register { @MainActor in self.transport }
            store = FluxStore(state: .init(), middlewares: [SessionMiddleware(transport: transport)])
        }
    }

    @Test func attachObservesOnlyTheRequestedRuntime() async throws {
        let fixture = Fixture()
        fixture.store.dispatch(.attachRequested(sessionId: "wanted"))
        try await waitUntil { await fixture.connection.observerCount > 0 }
        await fixture.connection.emit(.init(session: .init(sessionId: "other", projectPath: "/p")))
        try await Task.sleep(for: .milliseconds(20))
        #expect(fixture.store.state.projection == nil)
        await fixture.connection.emit(.init(session: .init(sessionId: "wanted", projectPath: "/p")))
        try await waitUntil { fixture.store.state.projection?.session.sessionId == "wanted" }
        #expect(fixture.store.state.canEditMessage)
    }

    @Test func sendRequestReservesSnapshotAndBlocksDuplicateAdmission() async throws {
        let fixture = Fixture()
        fixture.store.dispatch(.attachRequested(sessionId: "wanted"))
        await fixture.connection.emit(.init(session: .init(sessionId: "wanted", projectPath: "/p")))
        try await waitUntil { fixture.store.state.canSend }
        fixture.store.dispatch(.sendRequested(text: "First"))
        #expect(fixture.store.state.isSending)
        fixture.store.dispatch(.sendRequested(text: "Next"))
        try await waitUntil { await fixture.connection.sendCount == 1 }
        await fixture.connection.acceptSend()
        try await waitUntil { !fixture.store.state.isSending }
        #expect(await fixture.connection.receivedPrompts == ["First"])
        #expect(fixture.store.state.clearDraftMatching == "First")
    }

    @Test func stopRequestReachesTheConnectionOnceAndIgnoresDuplicates() async throws {
        let fixture = Fixture()
        fixture.store.dispatch(.attachRequested(sessionId: "wanted"))
        await fixture.connection.emit(.init(session: .init(sessionId: "wanted", projectPath: "/p"), status: .running))
        try await waitUntil { fixture.store.state.canStop }
        fixture.store.dispatch(.stopRequested())
        fixture.store.dispatch(.stopRequested())
        try await waitUntil { await fixture.connection.stopCount == 1 }
        try await waitUntil { !fixture.store.state.isStopping }
        #expect(await fixture.connection.stopCount == 1)
    }

    @Test func detachingInvalidatesQueuedMutationAndKeepsTheTransport() async throws {
        let fixture = Fixture()
        fixture.store.dispatch(.attachRequested(sessionId: "wanted"))
        await fixture.connection.emit(.init(session: .init(sessionId: "wanted", projectPath: "/p"), status: .running))
        try await waitUntil { fixture.store.state.canStop }
        fixture.store.dispatch(.stopRequested())
        fixture.store.dispatch(.detachRequested())
        try await Task.sleep(for: .milliseconds(50))
        #expect(fixture.store.state.observedSessionId == nil)
        #expect(fixture.store.state.projection == nil)
        // The workspace owns the connection: detaching a view never disposes it.
        #expect(await !fixture.connection.closed)
    }

    private func waitUntil(sourceLocation: SourceLocation = #_sourceLocation,
                           _ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while ContinuousClock.now < deadline {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Session effect did not settle", sourceLocation: sourceLocation)
    }
}

private actor SessionConnectionStub: PiDemoConnection {
    var closed = false
    var sendCount = 0
    var stopCount = 0
    var receivedPrompts: [String] = []
    private var observers: [UUID: AsyncStream<DemoSessionProjection>.Continuation] = [:]
    private var current: DemoSessionProjection?
    private var sendWait: CheckedContinuation<Void, Error>?

    var observerCount: Int { observers.count }
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func projections() async -> AsyncStream<DemoSessionProjection> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<DemoSessionProjection>.makeStream(bufferingPolicy: .bufferingNewest(1))
        if let current { continuation.yield(current) }
        observers[id] = continuation
        continuation.onTermination = { [weak self] _ in Task { await self?.remove(id) } }
        return stream
    }
    private func remove(_ id: UUID) { observers.removeValue(forKey: id) }
    func emit(_ projection: DemoSessionProjection) {
        current = projection
        for observer in observers.values { observer.yield(projection) }
    }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession { throw PiError.invalidState }
    func send(_ text: String) async throws {
        sendCount += 1
        receivedPrompts.append(text)
        try await withCheckedThrowingContinuation { sendWait = $0 }
    }
    func acceptSend(_ error: PiError? = nil) {
        if let error { sendWait?.resume(throwing: error) } else { sendWait?.resume() }
        sendWait = nil
    }
    func stop() async throws { stopCount += 1 }
    func disconnect() async { closed = true }
}
