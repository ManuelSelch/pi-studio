#if DEBUG
import Foundation
import PiSDK

/// Debug-only isolated UI fixture. Normal launches always use the real SDK.
actor UITestConnection: PiSessionConnection {
    private var state: PiConnectionState = .disconnected
    private var projection: DemoSessionProjection?
    private var closed = false
    private var turn = 0
    private var created = 0
    private var catalogueReady = false
    private var streaming: Task<Void, Never>?
    private let rejectSend: Bool
    private let unknownSend: Bool
    private let rejectOpen: Bool
    private var stateObservers: [UUID: AsyncStream<PiConnectionState>.Continuation] = [:]
    private var projectionObservers: [UUID: AsyncStream<DemoSessionProjection>.Continuation] = [:]
    private var catalogueObservers: [UUID: AsyncStream<PiCatalogue>.Continuation] = [:]
    private var runtimes: [PiRuntimeSummary] = [.init(sessionId: "ui-running", title: "Pocket navigation", projectPath: "/repo", projectName: "pi-studio", status: "running")]

    init(rejectSend: Bool = false, unknownSend: Bool = false, rejectOpen: Bool = false) {
        self.rejectSend = rejectSend; self.unknownSend = unknownSend; self.rejectOpen = rejectOpen
    }
    func states() async -> AsyncStream<PiConnectionState> {
        let id = UUID(); let (stream, updates) = AsyncStream<PiConnectionState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        updates.yield(state); stateObservers[id] = updates
        updates.onTermination = { [weak self] _ in Task { await self?.removeState(id) } }; return stream
    }
    private func removeState(_ id: UUID) { stateObservers.removeValue(forKey: id) }
    func projections() async -> AsyncStream<DemoSessionProjection> {
        let id = UUID(); let (stream, updates) = AsyncStream<DemoSessionProjection>.makeStream(bufferingPolicy: .bufferingNewest(1))
        if let projection { updates.yield(projection) }; projectionObservers[id] = updates
        updates.onTermination = { [weak self] _ in Task { await self?.removeProjection(id) } }; return stream
    }
    private func removeProjection(_ id: UUID) { projectionObservers.removeValue(forKey: id) }
    func catalogues() async -> AsyncStream<PiCatalogue> {
        let id = UUID(); let (stream, updates) = AsyncStream<PiCatalogue>.makeStream(bufferingPolicy: .bufferingNewest(1))
        updates.yield(catalogue); catalogueObservers[id] = updates
        updates.onTermination = { [weak self] _ in Task { await self?.removeCatalogue(id) } }; return stream
    }
    private func removeCatalogue(_ id: UUID) { catalogueObservers.removeValue(forKey: id) }
    private var catalogue: PiCatalogue {
        .init(projects: catalogueReady ? [
            .init(path: "/home/pi", name: "Quick Chats", quickChats: true,
                  sessions: [.init(path: "/history/quick", title: "Saved quick chat")]),
            .init(path: "/repo", name: "pi-studio", worktree: .init(branch: "feat/pocket")),
        ] : [], sessions: runtimes)
    }
    private func publishCatalogue() { for observer in catalogueObservers.values { observer.yield(catalogue) } }
    private func publishState(_ value: PiConnectionState) {
        state = value; for observer in stateObservers.values { observer.yield(value) }
    }
    func connect(takingControl: Bool) async throws {
        try await Task.sleep(for: .milliseconds(100))
        guard !closed, takingControl else { throw PiError.disconnected }
        publishState(.connected)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            await self?.finishCatalogue()
        }
    }
    private func finishCatalogue() {
        guard !closed else { return }; catalogueReady = true; publishCatalogue()
    }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession {
        try await connect(takingControl: takingControl)
        return try await createSession(projectPath: projectPath)
    }
    func createSession(projectPath: String) async throws -> DemoSession {
        guard !closed else { throw PiError.disconnected }
        created += 1
        let id = "ui-new-\(created)"
        runtimes.append(.init(sessionId: id, title: "New chat", projectPath: projectPath, projectName: projectPath == "/home/pi" ? "Quick Chats" : "pi-studio"))
        publishCatalogue()
        return select(id, projectPath)
    }
    func openSession(sessionPath: String) async throws -> DemoSession {
        try await Task.sleep(for: .milliseconds(100))
        guard !closed else { throw PiError.disconnected }
        if rejectOpen { throw PiError.rejected(code: "notFound", message: "History unavailable") }
        return select("ui-saved", "/home/pi", messages: [.init(id: "saved-answer", role: "assistant", text: "A saved answer from Quick Chats.")])
    }
    func attachSession(sessionId: String) async throws -> DemoSession {
        guard !closed else { throw PiError.disconnected }
        return select(sessionId, "/repo", status: .running, messages: [.init(id: "running-answer", role: "assistant", text: "Checking project navigation…", isPartial: true)])
    }
    private func select(_ id: String, _ path: String, status: DemoRunStatus = .idle, messages: [DemoMessage] = []) -> DemoSession {
        let session = DemoSession(sessionId: id, projectPath: path)
        projection = .init(session: session, messages: messages, status: status)
        publishState(.ready(session)); publish(status)
        return session
    }
    private func publish(_ status: DemoRunStatus, messages: [DemoMessage]? = nil) {
        guard let current = projection, !closed else { return }
        projection = .init(session: current.session, messages: messages ?? current.messages, status: status)
        for observer in projectionObservers.values { observer.yield(projection!) }
    }
    func send(_ text: String) async throws {
        try await Task.sleep(for: .milliseconds(100))
        guard !closed else { throw PiError.disconnected }
        if rejectSend { throw PiError.rejected(code: "sessionBusy", message: "Send rejected by the test runtime.") }
        if unknownSend {
            let error = PiError.requestExpired(outcomeUnknown: true)
            publishState(.failed(error)); throw error
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
        guard !closed else { return }
        closed = true; streaming?.cancel(); streaming = nil
        publishState(.disconnected)
        for observer in stateObservers.values { observer.finish() }; stateObservers = [:]
        for observer in projectionObservers.values { observer.finish() }; projectionObservers = [:]
        for observer in catalogueObservers.values { observer.finish() }; catalogueObservers = [:]
    }
}
#endif
