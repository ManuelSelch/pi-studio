import Foundation
import PiSDK
import Testing
@testable import pi_studio

private actor DemoConnectionStub: PiDemoConnection {
    var count = 0
    var closed = false
    var wait: CheckedContinuation<DemoSession, Error>?
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession {
        count += 1
        return try await withCheckedThrowingContinuation { wait = $0 }
    }
    func succeed() { wait?.resume(returning: DemoSession(sessionId: "demo", projectPath: "/tmp/demo")); wait = nil }
    func disconnect() async { closed = true; wait?.resume(throwing: PiError.disconnected); wait = nil }
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

    @Test func noConnectionWithoutExplicitConsent() async {
        let connection = DemoConnectionStub()
        let model = DemoSessionModel(makeConnection: { _ in connection })
        await model.connect(takingControl: false)
        #expect(await connection.count == 0)
        #expect(model.state == .disconnected)
    }
}
