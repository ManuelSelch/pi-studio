import Foundation
import PiSDK
import Testing
@testable import pi_studio

private actor DemoConnectionStub: PiDemoConnection {
    var count = 0
    var closed = false
    var wait: CheckedContinuation<DemoSession, Error>?
    var sendWait: CheckedContinuation<Void, Error>?
    var sendCount = 0
    var current: DemoSessionProjection?
    let (updates, continuation) = AsyncStream<DemoSessionProjection>.makeStream(bufferingPolicy: .bufferingNewest(1))
    func projections() async -> AsyncStream<DemoSessionProjection> { if let current { continuation.yield(current) }; return updates }
    func setProjection(_ value: DemoSessionProjection) { current = value; continuation.yield(value) }
    func send(_ text: String) async throws {
        sendCount += 1
        try await withCheckedThrowingContinuation { sendWait = $0 }
    }
    func settleSend(_ error: PiError? = nil) {
        if let error { sendWait?.resume(throwing: error) } else { sendWait?.resume() }
        sendWait = nil
    }
    func stop() async throws {
        if let current { setProjection(.init(session: current.session, messages: current.messages, status: .aborting)) }
    }
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession {
        count += 1
        return try await withCheckedThrowingContinuation { wait = $0 }
    }
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

@MainActor
struct pi_studioTests {
    @Test func explicitConnectionDisablesDuplicateCreateAndDisconnectDisposes() async {
        let connection = DemoConnectionStub()
        let model = DemoSessionModel(configuration: .init(endpoint: URL(string: "ws://127.0.0.1:8787/ws")!, projectPath: "/tmp/demo"), makeConnection: { _ in connection })
        #expect(model.state == .disconnected)
        let first = Task { await model.connect(takingControl: true) }
        while await connection.count == 0 { await Task.yield() }
        #expect(model.state == .connecting)
        await model.connect(takingControl: true)
        #expect(await connection.count == 1)
        await connection.succeed()
        await first.value
        #expect(model.state == .ready(DemoSession(sessionId: "demo", projectPath: "/tmp/demo")))
        await model.disconnect()
        #expect(model.state == .disconnected)
        #expect(await connection.closed)
    }

    @Test func disconnectWhileConnectingIgnoresObsoleteFailure() async {
        let connection = DemoConnectionStub()
        let model = DemoSessionModel(makeConnection: { _ in connection })
        let first = Task { await model.connect(takingControl: true) }
        while await connection.count == 0 { await Task.yield() }
        await model.disconnect()
        await first.value
        #expect(model.state == .disconnected)
        #expect(await connection.closed)
    }

    @Test func sendClearsDraftOnlyAfterAdmissionAndBlocksDuplicates() async throws {
        let (model, connection) = await connectedModel()
        model.draft = "Say hello"
        #expect(model.canSend)
        let send = Task { await model.send() }
        while await connection.sendCount == 0 { await Task.yield() }
        #expect(model.draft == "Say hello")
        #expect(!model.canSend)
        await model.send()
        #expect(await connection.sendCount == 1)
        await connection.settleSend()
        await send.value
        #expect(model.draft.isEmpty)
        await model.disconnect()
    }

    @Test(arguments: [false, true])
    func sendRejectionAndUnknownOutcomeRetainDraft(unknown: Bool) async {
        let (model, connection) = await connectedModel()
        model.draft = "Keep draft"
        let send = Task { await model.send() }
        while await connection.sendCount == 0 { await Task.yield() }
        await connection.settleSend(unknown ? .requestExpired(outcomeUnknown: true) : .rejected(code: "sessionBusy", message: "Not now"))
        await send.value
        #expect(model.draft == "Keep draft")
        #expect(model.errorMessage != nil)
        if unknown { #expect(model.errorMessage!.contains("unknown")) }
        await model.disconnect()
    }

    @Test func projectionDrivesGeneratingAndStoppingWithoutDiscardingText() async {
        let (model, connection) = await connectedModel()
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        let text = DemoMessage(id: "a", role: "assistant", text: "Partial", isPartial: true)
        await connection.setProjection(.init(session: session, messages: [text], status: .running))
        while model.projection?.status != .running { await Task.yield() }
        #expect(model.statusText == "Generating…")
        #expect(model.requiresDisconnectWarning)
        await model.stop()
        while model.projection?.status != .aborting { await Task.yield() }
        #expect(model.statusText == "Stopping…")
        #expect(!model.canSend)
        await connection.setProjection(.init(session: session, messages: [text], status: .idle))
        while model.projection?.status != .idle { await Task.yield() }
        #expect(model.statusText == "Ready")
        await model.disconnect()
        #expect(model.projection?.messages == [text])
    }

    private func connectedModel() async -> (DemoSessionModel, DemoConnectionStub) {
        let connection = DemoConnectionStub()
        let model = DemoSessionModel(makeConnection: { _ in connection })
        let connect = Task { await model.connect(takingControl: true) }
        while await connection.count == 0 { await Task.yield() }
        await connection.succeed(); await connect.value
        while model.projection == nil { await Task.yield() }
        return (model, connection)
    }

    @Test func noConnectionWithoutExplicitConsent() async {
        let connection = DemoConnectionStub()
        let model = DemoSessionModel(makeConnection: { _ in connection })
        await model.connect(takingControl: false)
        #expect(await connection.count == 0)
        #expect(model.state == .disconnected)
    }
}
