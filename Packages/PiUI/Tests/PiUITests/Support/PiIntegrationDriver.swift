import FactoryKit
import Flux
import Foundation
import PiSDK
import Testing
@testable import PiUI

/// Conversation-level test API: attach, transcript, send/stop admission. The transport belongs
/// to the workspace in production, so here the driver publishes a stub connection into the
/// same `SessionTransport` seam the workspace uses.
@MainActor
final class PiIntegrationDriver {
    let session: IntegrationSessionDriver
    let chat: IntegrationChatDriver
    let server: IntegrationServerDriver
    private let context: IntegrationContext

    /// Driver-internal convenience: scenarios assert on the conversation store directly.
    var state: SessionFeature.State { context.store.state }
    func wait(_ description: String, _ condition: @escaping () async -> Bool) async throws {
        try await context.wait(description) { await condition() }
    }

    private init() {
        let context = IntegrationContext()
        self.context = context
        session = IntegrationSessionDriver(context)
        chat = IntegrationChatDriver(context)
        server = IntegrationServerDriver(context)
    }

    static func run(_ scenario: (PiIntegrationDriver) async throws -> Void) async throws {
        let app = PiIntegrationDriver()
        do {
            try await scenario(app)
            await app.context.dispose()
        } catch {
            await app.context.dispose()
            throw error
        }
    }
}

@MainActor
final class IntegrationSessionDriver {
    private let context: IntegrationContext
    fileprivate init(_ context: IntegrationContext) { self.context = context }

    /// The workspace attaches a runtime; the conversation then observes it.
    func attach(_ sessionId: String = "middleware") async throws {
        context.store.dispatch(.attachRequested(sessionId: sessionId))
        await context.stub.emit(.init(session: .init(sessionId: sessionId, projectPath: "/tmp/demo")))
        try await context.wait("ready conversation") { self.context.store.state.canEditMessage }
    }
    func detach() { context.store.dispatch(.detachRequested()) }
    func releaseStore() {
        context.store.dispatch(.detachRequested())
        context.releaseStore()
    }
    func shouldBeDisconnected(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.connection == .disconnected, sourceLocation: sourceLocation)
    }
    func shouldBeReady(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.canEditMessage, sourceLocation: sourceLocation)
    }
    func statusShouldBe(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.statusText == text, sourceLocation: sourceLocation)
    }
    func shouldShowError(containing text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.errorMessage?.contains(text) == true, sourceLocation: sourceLocation)
    }
    func shouldWarnBeforeDisconnect(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.requiresDisconnectWarning, sourceLocation: sourceLocation)
    }
    func waitUntilStopping(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("stopping", sourceLocation: sourceLocation) { self.context.store.state.statusText == "Stopping…" }
    }
    func transcriptShouldHaveNoForeignSession(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.projection?.session.sessionId == context.store.state.observedSessionId,
                sourceLocation: sourceLocation)
    }
}

@MainActor
final class IntegrationChatDriver {
    private let context: IntegrationContext
    fileprivate init(_ context: IntegrationContext) { self.context = context }

    var clearInstruction: String? { context.store.state.clearDraftMatching }
    func clearInstructionShouldBe(_ text: String?, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.clearDraftMatching == text, sourceLocation: sourceLocation)
    }
    func consumeClearInstruction() { context.store.dispatch(.clearDraftConsumed) }
    func submit(_ text: String) { context.store.dispatch(.sendRequested(text: text)) }
    func beginSend(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let previous = await context.stub.sendCount
        submit(text)
        try await context.wait("send admission request", sourceLocation: sourceLocation) { await self.context.stub.sendCount > previous }
    }
    func beginSendThenSubmit(_ snapshot: String, duplicate: String,
                             sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await beginSend(snapshot, sourceLocation: sourceLocation)
        submit(duplicate)
    }
    func sendPrompt(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await beginSend(text, sourceLocation: sourceLocation)
        await context.stub.acceptSend()
        try await context.wait("admitted send", sourceLocation: sourceLocation) { !self.context.store.state.isSending }
        #expect(context.store.state.errorMessage == nil, sourceLocation: sourceLocation)
    }
    func stop() { context.store.dispatch(.stopRequested()) }
    func stopTwice() {
        stop()
        stop()
    }
    func shouldAllowSend(_ allowed: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.canSend == allowed, sourceLocation: sourceLocation)
    }
    func shouldHavePendingSend(_ pending: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.isSending == pending, sourceLocation: sourceLocation)
    }
    func messagesShouldBe(_ texts: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.store.state.projection?.messages.map(\.text) == texts, sourceLocation: sourceLocation)
    }
}

/// Fixture controls are distinct from app actions: no test pretends stub events are UI input.
@MainActor
final class IntegrationServerDriver {
    private let context: IntegrationContext
    fileprivate init(_ context: IntegrationContext) { self.context = context }

    func emit(_ projection: DemoSessionProjection) async throws {
        await context.stub.emit(projection)
    }
    func streamReply(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let session = DemoSession(sessionId: "middleware", projectPath: "/tmp/demo")
        await context.stub.emit(.init(session: session, messages: [.init(id: "a", role: "assistant", text: text, isPartial: true)], status: .running))
        try await context.wait("streaming projection", sourceLocation: sourceLocation) { self.context.store.state.projection?.status == .running }
    }
    func finishReply(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        await context.stub.finishReply()
        try await context.wait("idle projection", sourceLocation: sourceLocation) { self.context.store.state.projection?.status == .idle }
    }
    func acceptSend() async { await context.stub.acceptSend() }
    func rejectSend() async { await context.stub.acceptSend(.rejected(code: "sessionBusy", message: "Not now")) }
    func loseSendReceipt() async { await context.stub.acceptSend(.requestExpired(outcomeUnknown: true)) }
    func shouldHaveSendCount(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.sendCount == count, sourceLocation: sourceLocation)
    }
    func shouldHaveStopCount(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.stopCount == count, sourceLocation: sourceLocation)
    }
    func waitForStops(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("stop count \(count)", sourceLocation: sourceLocation) {
            await self.context.stub.stopCount >= count
        }
    }
    func receivedPromptsShouldBe(_ texts: [String], sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.receivedPrompts == texts, sourceLocation: sourceLocation)
    }
    func shouldRemainConnected(sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await !context.stub.closed, sourceLocation: sourceLocation)
    }
}

@MainActor
fileprivate final class IntegrationContext {
    let container = Container()
    let stub = ConversationConnectionStub()
    var store: FluxStore<SessionFeature>!

    init() {
        let transport = SessionTransport()
        transport.publish(stub)
        container.sessionTransport.register { @MainActor in transport }
        store = FluxStore(state: .init(), middlewares: [SessionMiddleware(transport: transport)])
    }

    func releaseStore() { store = nil }
    func dispose() async { await stub.release() }

    func wait(_ description: String, sourceLocation: SourceLocation = #_sourceLocation,
              until predicate: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while ContinuousClock.now < deadline {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for \(description)", sourceLocation: sourceLocation)
        throw DriverTimeout()
    }

    struct DriverTimeout: Error {}
}

/// A conversation-shaped connection: one projection stream, held send admission, counters.
fileprivate actor ConversationConnectionStub: PiDemoConnection {
    var closed = false
    var sendCount = 0
    var stopCount = 0
    var receivedPrompts: [String] = []
    var attachedSessionId: String?
    private var current: DemoSessionProjection?
    private var sendWait: CheckedContinuation<Void, Error>?
    private var observers: [UUID: AsyncStream<DemoSessionProjection>.Continuation] = [:]

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
        if attachedSessionId == nil { attachedSessionId = projection.session.sessionId }
        for observer in observers.values { observer.yield(projection) }
    }
    func finishReply() {
        guard let current else { return }
        emit(.init(session: current.session, messages: current.messages, status: .idle))
    }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession { throw PiError.invalidState }
    func send(_ text: String) async throws {
        sendCount += 1
        receivedPrompts.append(text)
        guard sendWait == nil else { throw PiError.rejected(code: "sessionBusy", message: "Send already pending") }
        try await withCheckedThrowingContinuation { sendWait = $0 }
    }
    func acceptSend(_ error: PiError? = nil) {
        if let error { sendWait?.resume(throwing: error) } else { sendWait?.resume() }
        sendWait = nil
    }
    func stop() async throws {
        stopCount += 1
        guard let current else { return }
        emit(.init(session: current.session, messages: current.messages, status: .aborting))
    }
    func disconnect() async { closed = true }
    func release() {
        sendWait?.resume(throwing: PiError.disconnected); sendWait = nil
        for observer in observers.values { observer.finish() }
        observers = [:]
    }
}
