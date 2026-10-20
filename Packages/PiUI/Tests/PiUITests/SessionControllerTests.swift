import Foundation
import PiSDK
import Testing
import PiUI

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

@MainActor
struct SessionControllerTests {
    @Test func explicitConnectionDisablesDuplicateCreateAndDisconnectDisposes() async throws {
        let connection = DemoConnectionStub()
        let model = SessionController(configuration: .init(endpoint: URL(string: "ws://127.0.0.1:8787/ws")!, projectPath: "/tmp/demo"), makeConnection: { _ in connection })
        #expect(model.state.connection == .disconnected)
        let first = Task { await model.connect(takingControl: true) }
        try await waitUntil { await connection.count > 0 }
        #expect(model.state.connection == .connecting)
        await model.connect(takingControl: true)
        #expect(await connection.count == 1)
        await connection.succeed()
        await first.value
        #expect(model.state.connection == .ready(DemoSession(sessionId: "demo", projectPath: "/tmp/demo")))
        await model.disconnect()
        #expect(model.state.connection == .disconnected)
        #expect(await connection.closed)
    }

    @Test func disconnectWhileConnectingIgnoresObsoleteFailure() async throws {
        let connection = DemoConnectionStub()
        let model = SessionController(makeConnection: { _ in connection })
        let first = Task { await model.connect(takingControl: true) }
        try await waitUntil { await connection.count > 0 }
        await model.disconnect()
        await first.value
        #expect(model.state.connection == .disconnected)
        #expect(await connection.closed)
    }

    @Test func sendClearsDraftOnlyAfterAdmissionAndBlocksDuplicates() async throws {
        let (model, connection) = try await connectedModel()
        model.setDraft("Say hello")
        #expect(model.state.canSend)
        let send = Task { await model.send() }
        try await waitUntil { await connection.sendCount > 0 }
        #expect(model.state.draft == "Say hello")
        #expect(!model.state.canSend)
        await model.send()
        #expect(await connection.sendCount == 1)
        await connection.settleSend()
        await send.value
        #expect(model.state.draft.isEmpty)
        await model.disconnect()
    }

    @Test(arguments: [false, true])
    func sendRejectionAndUnknownOutcomeRetainDraft(unknown: Bool) async throws {
        let (model, connection) = try await connectedModel()
        model.setDraft("Keep draft")
        let send = Task { await model.send() }
        try await waitUntil { await connection.sendCount > 0 }
        await connection.settleSend(unknown ? .requestExpired(outcomeUnknown: true) : .rejected(code: "sessionBusy", message: "Not now"))
        await send.value
        #expect(model.state.draft == "Keep draft")
        #expect(model.state.errorMessage != nil)
        if unknown { #expect(model.state.errorMessage!.contains("unknown")) }
        await model.disconnect()
    }

    @Test func projectionDrivesGeneratingAndStoppingWithoutDiscardingText() async throws {
        let (model, connection) = try await connectedModel()
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        let text = DemoMessage(id: "a", role: "assistant", text: "Partial", isPartial: true)
        await connection.setProjection(.init(session: session, messages: [text], status: .running))
        try await waitUntil { model.state.projection?.status == .running }
        #expect(model.state.statusText == "Generating…")
        #expect(model.state.requiresDisconnectWarning)
        await model.stop()
        try await waitUntil { model.state.projection?.status == .aborting }
        #expect(model.state.statusText == "Stopping…")
        #expect(!model.state.canSend)
        await connection.setProjection(.init(session: session, messages: [text], status: .idle))
        try await waitUntil { model.state.projection?.status == .idle }
        #expect(model.state.statusText == "Ready")
        await model.disconnect()
        #expect(model.state.projection?.messages == [text])
    }

    private func connectedModel() async throws -> (SessionController, DemoConnectionStub) {
        let connection = DemoConnectionStub()
        let model = SessionController(makeConnection: { _ in connection })
        let connect = Task { await model.connect(takingControl: true) }
        try await waitUntil { await connection.count > 0 }
        await connection.succeed(); await connect.value
        try await waitUntil { model.state.projection != nil }
        return (model, connection)
    }

    private func waitUntil(_ predicate: () async -> Bool) async throws {
        for _ in 0..<200 {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw PiError.requestExpired(outcomeUnknown: false)
    }

    @Test func connectionFailureIsVisibleAndDisposed() async throws {
        let connection = DemoConnectionStub()
        let model = SessionController(makeConnection: { _ in connection })
        let connect = Task { await model.connect(takingControl: true) }
        try await waitUntil { await connection.count > 0 }
        let error = PiError.transport(message: "Connection refused", outcomeUnknown: false)
        await connection.fail(error)
        await connect.value
        #expect(model.state.connection == .failed(error))
        #expect(model.state.errorMessage == "Connection refused")
        #expect(await connection.closed)
    }

    @Test func disconnectDuringPendingSendRetainsDraftAndIgnoresLateFailure() async throws {
        let (model, connection) = try await connectedModel()
        model.setDraft("Keep this")
        let send = Task { await model.send() }
        try await waitUntil { await connection.sendCount > 0 }
        await model.disconnect()
        await send.value
        #expect(model.state.connection == .disconnected)
        #expect(model.state.draft == "Keep this")
        #expect(model.state.errorMessage?.contains("outcome unknown") == true)
        #expect(!model.state.isSending)
    }

    @Test func releasingConnectedControllerDisposesConnection() async throws {
        let connection = DemoConnectionStub()
        weak var weakModel: SessionController?
        do {
            let model = SessionController(makeConnection: { _ in connection })
            weakModel = model
            let connect = Task { await model.connect(takingControl: true) }
            try await waitUntil { await connection.count > 0 }
            await connection.succeed()
            await connect.value
            try await waitUntil { model.state.projection != nil }
        }
        try await waitUntil { weakModel == nil }
        try await waitUntil { await connection.closed }
    }

    @Test func noConnectionWithoutExplicitConsent() async throws {
        let connection = DemoConnectionStub()
        let model = SessionController(makeConnection: { _ in connection })
        await model.connect(takingControl: false)
        #expect(await connection.count == 0)
        #expect(model.state.connection == .disconnected)
    }
}
