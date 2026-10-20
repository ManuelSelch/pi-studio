import Foundation
import PiSDK
import Synchronization
import PiUI
import Testing

/// Semantic test API. Only this layer knows controllers, SDK projections and stubs.
@MainActor
final class PiIntegrationDriver {
    let session: IntegrationSessionDriver
    let chat: IntegrationChatDriver
    let server: IntegrationServerDriver
    let settings: IntegrationSettingsDriver
    private let context: IntegrationContext

    private init(configuration: SessionConfiguration?) {
        let context = IntegrationContext(configuration: configuration)
        self.context = context
        session = IntegrationSessionDriver(context)
        chat = IntegrationChatDriver(context)
        server = IntegrationServerDriver(context)
        settings = IntegrationSettingsDriver(context)
    }

    /// A nil configuration uses an isolated stub; explicit configuration opts into transport.
    /// Always settle pending work and dispose, including when a scenario throws.
    static func run(configuration: SessionConfiguration? = nil,
                    _ scenario: (PiIntegrationDriver) async throws -> Void) async throws {
        let app = PiIntegrationDriver(configuration: configuration)
        do {
            try await scenario(app)
            await app.context.dispose()
        } catch {
            await app.context.dispose()
            throw error
        }
    }
}

fileprivate final class EndpointLog: Sendable {
    let values = Mutex<[String]>([])
}

@MainActor
fileprivate final class IntegrationEndpointSettings: EndpointSettingsService {
    var value: String?
    func load() -> String? { value }
    func save(_ endpoint: String) throws { value = endpoint }
}

@MainActor
final class IntegrationSettingsDriver {
    private let context: IntegrationContext
    fileprivate init(_ context: IntegrationContext) { self.context = context }
    func open() { context.settings.open() }
    func enterEndpoint(_ value: String) { context.settings.setDraft(value) }
    func save() { context.settings.save() }
    func cancel() { context.settings.cancel() }
}

@MainActor
fileprivate final class IntegrationContext {
    var controller: SessionController?
    let settings: SettingsController
    let endpoints = EndpointLog()
    let stub: DemoConnectionStub?
    var connecting: Task<Void, Never>?
    var sending: Task<Void, Never>?
    var model: SessionController { controller! }

    init(configuration: SessionConfiguration?) {
        let settings = SettingsController(service: IntegrationEndpointSettings())
        self.settings = settings
        if let configuration {
            stub = nil
            controller = SessionController(configuration: configuration)
        } else {
            let stub = DemoConnectionStub()
            self.stub = stub
            let endpoints = endpoints
            controller = SessionController(endpointProvider: { settings.endpoint }, makeConnection: { endpoint in
                endpoints.values.withLock { $0.append(endpoint.absoluteString) }
                return stub
            })
        }
    }

    func dispose() async {
        await controller?.disconnect()
        await connecting?.value; connecting = nil
        await sending?.value; sending = nil
    }

    func wait(_ description: String, sourceLocation: SourceLocation,
              until predicate: () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while ContinuousClock.now < deadline {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for \(description); status: \(controller?.state.statusText ?? "released")", sourceLocation: sourceLocation)
        throw DriverTimeout()
    }

    struct DriverTimeout: Error {}
}

@MainActor
final class IntegrationSessionDriver {
    private let context: IntegrationContext
    fileprivate init(_ context: IntegrationContext) { self.context = context }

    func connect(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        if context.stub != nil {
            try await beginConnect(sourceLocation: sourceLocation)
            await context.stub!.succeed()
            await context.connecting?.value; context.connecting = nil
        } else {
            await context.model.connect(takingControl: true)
        }
        try await context.wait("ready session", sourceLocation: sourceLocation) { self.context.model.state.canEditMessage }
    }

    func beginConnect(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let stub = try #require(context.stub, sourceLocation: sourceLocation)
        try #require(context.connecting == nil, sourceLocation: sourceLocation)
        let model = context.model
        let previous = await stub.count
        context.connecting = Task { await model.connect(takingControl: true) }
        try await context.wait("connection request", sourceLocation: sourceLocation) { await stub.count > previous }
    }

    func connectAgain() async { await context.model.connect(takingControl: true) }
    func connectWithoutConsent() async { await context.model.connect(takingControl: false) }
    func disconnect() async { await context.dispose() }

    func releaseController(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        weak var model = context.controller
        context.controller = nil
        try await context.wait("controller release and disposal", sourceLocation: sourceLocation) {
            let closed = await self.context.stub?.closed == true
            return model == nil && closed
        }
    }

    func endpointShouldBe(_ endpoint: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.connectionEndpoint?.absoluteString == endpoint, sourceLocation: sourceLocation)
    }

    func shouldBeDisconnected(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.connection == .disconnected, sourceLocation: sourceLocation)
    }
    func shouldBeConnecting(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.connection == .connecting, sourceLocation: sourceLocation)
    }
    func shouldBeReady(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.canEditMessage, sourceLocation: sourceLocation)
        #expect(context.model.state.statusText == "Ready", sourceLocation: sourceLocation)
    }
    func statusShouldBe(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.statusText == text, sourceLocation: sourceLocation)
    }
    func shouldShowError(containing text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.errorMessage?.contains(text) == true, sourceLocation: sourceLocation)
    }
    func shouldWarnBeforeDisconnect(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.requiresDisconnectWarning, sourceLocation: sourceLocation)
    }
    func waitUntilReady(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("settled idle session", sourceLocation: sourceLocation) { self.context.model.state.canEditMessage }
    }
    func waitUntilStopping(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("stopping", sourceLocation: sourceLocation) { self.context.model.state.statusText == "Stopping…" }
    }
}

@MainActor
final class IntegrationChatDriver {
    private let context: IntegrationContext
    fileprivate init(_ context: IntegrationContext) { self.context = context }

    func enterDraft(_ text: String) { context.model.setDraft(text) }
    func sendPrompt(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        enterDraft(text)
        try #require(context.model.state.canSend, "Prompt requires an idle, ready session", sourceLocation: sourceLocation)
        if let stub = context.stub {
            try await beginSend(sourceLocation: sourceLocation)
            await stub.settleSend()
            await context.sending?.value; context.sending = nil
        } else {
            await context.model.send()
        }
        #expect(context.model.state.errorMessage == nil, sourceLocation: sourceLocation)
    }
    func beginSend(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let stub = try #require(context.stub, sourceLocation: sourceLocation)
        try #require(context.sending == nil, sourceLocation: sourceLocation)
        let previous = await stub.sendCount
        let model = context.model
        context.sending = Task { await model.send() }
        try await context.wait("send admission request", sourceLocation: sourceLocation) { await stub.sendCount > previous }
    }
    func sendAgain() async { await context.model.send() }
    func stop() async { await context.model.stop() }
    func draftShouldBe(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.draft == text, sourceLocation: sourceLocation)
    }
    func shouldAllowSend(_ allowed: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.canSend == allowed, sourceLocation: sourceLocation)
    }
    func shouldHavePendingSend(_ pending: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.isSending == pending, sourceLocation: sourceLocation)
    }
    func messagesShouldBe(_ texts: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.projection?.messages.map(\.text) == texts, sourceLocation: sourceLocation)
    }
    func waitForPartialReply(messageCount: Int, sourceLocation: SourceLocation = #_sourceLocation) async throws -> String {
        try await context.wait("partial assistant reply #\(messageCount)", sourceLocation: sourceLocation) {
            let state = self.context.model.state
            return state.canStop && state.projection?.messages.count == messageCount
                && state.projection?.messages.last?.role == "assistant"
                && state.projection?.messages.last?.isPartial == true
                && state.projection?.messages.last?.text.isEmpty == false
        }
        return context.model.state.projection!.messages.last!.text
    }
    struct TranscriptSnapshot {
        fileprivate let messages: [DemoMessage]
    }
    func captureTranscript() -> TranscriptSnapshot {
        TranscriptSnapshot(messages: context.model.state.projection?.messages ?? [])
    }
    func transcriptShouldBe(_ snapshot: TranscriptSnapshot, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.projection?.messages == snapshot.messages, sourceLocation: sourceLocation)
    }
    func captureLastReply(sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        let text = try #require(context.model.state.projection?.messages.last?.text, sourceLocation: sourceLocation)
        try #require(!text.isEmpty, sourceLocation: sourceLocation)
        return text
    }
    func lastReplyShouldDiffer(from partial: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.projection?.messages.last?.text != partial, sourceLocation: sourceLocation)
    }
    func shouldHaveMessageCount(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.model.state.projection?.messages.count == count, sourceLocation: sourceLocation)
    }
}

/// Fixture controls are distinct from app actions: no test pretends stub events are UI input.
@MainActor
final class IntegrationServerDriver {
    private let context: IntegrationContext
    fileprivate init(_ context: IntegrationContext) { self.context = context }
    private var stub: DemoConnectionStub { context.stub! }

    func acceptConnection(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        await stub.succeed()
        await context.connecting?.value; context.connecting = nil
        try await context.wait("initial projection", sourceLocation: sourceLocation) { self.context.model.state.projection != nil }
    }
    func rejectConnection(_ message: String) async {
        await stub.fail(.transport(message: message, outcomeUnknown: false))
        await context.connecting?.value; context.connecting = nil
    }
    private func settleSend(_ error: PiError? = nil) async {
        await stub.settleSend(error)
        await context.sending?.value; context.sending = nil
    }
    func acceptSend() async { await settleSend() }
    func rejectSend() async { await settleSend(.rejected(code: "sessionBusy", message: "Not now")) }
    func loseSendReceipt() async { await settleSend(.requestExpired(outcomeUnknown: true)) }
    func streamReply(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        await stub.setProjection(.init(session: session, messages: [.init(id: "a", role: "assistant", text: text, isPartial: true)], status: .running))
        try await context.wait("streaming projection", sourceLocation: sourceLocation) { self.context.model.state.projection?.status == .running }
    }
    func finishReply(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        await stub.finishReply()
        try await context.wait("idle projection", sourceLocation: sourceLocation) { self.context.model.state.projection?.status == .idle }
    }
    func connectionEndpointsShouldBe(_ endpoints: [String], sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(context.endpoints.values.withLock { $0 } == endpoints, sourceLocation: sourceLocation)
    }
    func projectPathShouldBe(_ path: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await stub.projectPath == path, sourceLocation: sourceLocation)
    }

    func shouldHaveConnectionCount(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await stub.count == count, sourceLocation: sourceLocation)
    }
    func shouldHaveSendCount(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await stub.sendCount == count, sourceLocation: sourceLocation)
    }
    func receivedPromptsShouldBe(_ texts: [String], sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await stub.receivedPrompts == texts, sourceLocation: sourceLocation)
    }
    func shouldBeDisposed(sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await stub.closed, sourceLocation: sourceLocation)
    }
}

fileprivate actor DemoConnectionStub: PiDemoConnection {
    var count = 0
    var projectPath: String?
    var closed = false
    var wait: CheckedContinuation<DemoSession, Error>?
    var sendWait: CheckedContinuation<Void, Error>?
    var sendCount = 0
    var receivedPrompts: [String] = []
    var current: DemoSessionProjection?
    var (updates, continuation) = AsyncStream<DemoSessionProjection>.makeStream(bufferingPolicy: .bufferingNewest(1))
    func projections() async -> AsyncStream<DemoSessionProjection> { if let current { continuation.yield(current) }; return updates }
    func setProjection(_ value: DemoSessionProjection) { current = value; continuation.yield(value) }
    func send(_ text: String) async throws {
        sendCount += 1
        receivedPrompts.append(text)
        guard sendWait == nil else { throw PiError.rejected(code: "sessionBusy", message: "Send already pending") }
        try await withCheckedThrowingContinuation { sendWait = $0 }
    }
    func settleSend(_ error: PiError? = nil) {
        if let error { sendWait?.resume(throwing: error) } else { sendWait?.resume() }
        sendWait = nil
    }
    func stop() async throws {
        if let current { setProjection(.init(session: current.session, messages: current.messages, status: .aborting)) }
    }
    func finishReply() {
        if let current { setProjection(.init(session: current.session, messages: current.messages, status: .idle)) }
    }
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession {
        if closed {
            (updates, continuation) = AsyncStream<DemoSessionProjection>.makeStream(bufferingPolicy: .bufferingNewest(1))
            closed = false
        }
        count += 1
        self.projectPath = projectPath
        guard wait == nil else { throw PiError.rejected(code: "sessionBusy", message: "Connection already pending") }
        return try await withCheckedThrowingContinuation { wait = $0 }
    }
    func fail(_ error: PiError) { wait?.resume(throwing: error); wait = nil }
    func succeed() {
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        current = .init(session: session)
        wait?.resume(returning: session); wait = nil
    }
    func disconnect() async {
        closed = true; wait?.resume(throwing: PiError.disconnected); wait = nil
        sendWait?.resume(throwing: PiError.transport(message: "Disconnected", outcomeUnknown: true)); sendWait = nil
        continuation.finish()
    }
}
