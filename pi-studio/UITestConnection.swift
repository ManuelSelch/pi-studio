#if DEBUG
import Foundation
import PiSDK

/// Debug-only native UI test double. Never selected by normal app launches;
/// deliberately uses public SDK projections rather than a second wire protocol.
actor UITestConnection: PiDemoConnection {
    private var state: PiConnectionState = .disconnected
    private var projection: DemoSessionProjection?
    private var closed = false
    private var turn = 0
    private var streaming: Task<Void, Never>?
    private let rejectSend: Bool
    private let unknownSend: Bool
    private let (stateStream, stateUpdates) = AsyncStream<PiConnectionState>.makeStream(bufferingPolicy: .bufferingNewest(1))
    private let (sessionStream, sessionUpdates) = AsyncStream<DemoSessionProjection>.makeStream(bufferingPolicy: .bufferingNewest(1))

    init(rejectSend: Bool = false, unknownSend: Bool = false) {
        self.rejectSend = rejectSend; self.unknownSend = unknownSend
    }
    func states() async -> AsyncStream<PiConnectionState> { stateUpdates.yield(state); return stateStream }
    func projections() async -> AsyncStream<DemoSessionProjection> {
        if let projection { sessionUpdates.yield(projection) }
        return sessionStream
    }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession {
        try await Task.sleep(for: .milliseconds(100))
        guard !closed, takingControl else { throw PiError.disconnected }
        let session = DemoSession(sessionId: "ui-demo", projectPath: projectPath)
        projection = .init(session: session)
        state = .ready(session); stateUpdates.yield(state)
        return session
    }
    private func publish(_ status: DemoRunStatus, messages: [DemoMessage]? = nil) {
        guard let current = projection, !closed else { return }
        projection = .init(session: current.session, messages: messages ?? current.messages, status: status)
        sessionUpdates.yield(projection!)
    }
    func send(_ text: String) async throws {
        try await Task.sleep(for: .milliseconds(100))
        guard !closed else { throw PiError.disconnected }
        if rejectSend { throw PiError.rejected(code: "sessionBusy", message: "Send rejected by the test runtime.") }
        if unknownSend {
            let error = PiError.requestExpired(outcomeUnknown: true)
            state = .failed(error); stateUpdates.yield(state)
            throw error
        }
        turn += 1
        let currentTurn = turn
        var messages = projection!.messages
        messages.append(.init(id: "user-\(turn)", role: "user", text: text))
        messages.append(.init(id: "assistant-\(turn)", role: "assistant", text: "Hello", isPartial: true))
        publish(.running, messages: messages)
        streaming = Task { [weak self] in
            for word in " from the demo. This reply is streaming a little at a time.".split(separator: " ") {
                do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
                await self?.append(" " + word, turn: currentTurn)
            }
            await self?.complete(turn: currentTurn)
        }
    }
    private func append(_ text: String, turn: Int) {
        guard !closed, turn == self.turn, projection?.status == .running, var messages = projection?.messages, let previous = messages.popLast() else { return }
        messages.append(.init(id: previous.id, role: previous.role, text: previous.text + text, isPartial: true))
        publish(.running, messages: messages)
    }
    private func complete(turn: Int) {
        guard !closed, turn == self.turn, var messages = projection?.messages, let previous = messages.popLast() else { return }
        messages.append(.init(id: previous.id, role: previous.role, text: previous.text))
        publish(.idle, messages: messages)
    }
    func stop() async throws {
        streaming?.cancel(); streaming = nil
        publish(.aborting)
        try await Task.sleep(for: .seconds(2))
        publish(.idle)
    }
    func disconnect() async {
        closed = true; streaming?.cancel(); streaming = nil
        state = .disconnected; stateUpdates.yield(state)
        stateUpdates.finish(); sessionUpdates.finish()
    }
}
#endif
