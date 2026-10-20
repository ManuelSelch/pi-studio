import Foundation
import Observation
import PiSDK

nonisolated struct DemoConfiguration: Sendable {
    let endpoint: URL
    let projectPath: String

    // Simulator-only development defaults. The directory is on the server.
    static let development = DemoConfiguration(
        endpoint: URL(string: "ws://localhost:8787/ws")!,
        projectPath: "/tmp/pi-studio-demo"
    )
}

/// App-owned drafts, action guards and presentation. Wire data and the transcript
/// are reduced exclusively by PiSDK, never reconstructed optimistically here.
@MainActor @Observable
final class DemoSessionModel {
    private(set) var state: PiConnectionState = .disconnected
    private(set) var projection: DemoSessionProjection?
    var draft = ""
    private(set) var isSending = false
    private(set) var isStopping = false
    private var actionError: String?
    let configuration: DemoConfiguration
    @ObservationIgnored private let makeConnection: @Sendable (URL) -> any PiDemoConnection
    @ObservationIgnored private var connection: (any PiDemoConnection)?
    @ObservationIgnored private var observation: Task<Void, Never>?
    @ObservationIgnored private var sessionObservation: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()

    init(configuration: DemoConfiguration = .development,
         makeConnection: @escaping @Sendable (URL) -> any PiDemoConnection = { PiClient(endpoint: $0) }) {
        self.configuration = configuration
        self.makeConnection = makeConnection
    }

    var canConnect: Bool {
        switch state { case .disconnected, .failed: true; default: false }
    }
    var canEditMessage: Bool {
        guard case .ready = state else { return false }
        return projection?.status == .idle && !isSending && !isStopping
    }
    var canSend: Bool { canEditMessage && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canStop: Bool {
        guard case .ready = state else { return false }
        return projection?.status == .running && !isSending && !isStopping
    }
    var requiresDisconnectWarning: Bool {
        isSending || isStopping || (!canConnect && projection != nil && projection?.status != .idle)
    }
    var statusText: String {
        switch state {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .failed(let error): return error.isOutcomeUnknown ? "Outcome unknown" : "Connection failed"
        case .ready:
            if isStopping || projection?.status == .aborting { return "Stopping…" }
            if isSending || projection?.status == .starting || projection?.status == .running { return "Generating…" }
            return "Ready"
        }
    }
    var errorMessage: String? {
        if case .failed(let error) = state { return error.localizedDescription }
        return actionError ?? projection?.error
    }
    var hint: String {
        if case .connecting = state { return "Initializing and creating the demo…" }
        if requiresDisconnectWarning { return "Partial text stays visible." }
        return canConnect ? "Connect to start a fresh demo." : "One message at a time."
    }

    func connect(takingControl: Bool) async {
        guard takingControl, canConnect else { return }
        let token = UUID(); generation = token
        observation?.cancel(); sessionObservation?.cancel()
        projection = nil; actionError = nil; isSending = false; isStopping = false
        state = .connecting
        let previous = connection; connection = nil
        await previous?.disconnect()
        guard generation == token else { return }
        let client = makeConnection(configuration.endpoint)
        connection = client
        do {
            let session = try await client.connectDemo(projectPath: configuration.projectPath, takingControl: true)
            guard generation == token else { return }
            state = .ready(session)
            observation = Task { [weak self] in
                for await state in await client.states() {
                    guard !Task.isCancelled, let self, self.generation == token else { return }
                    self.state = state
                }
            }
            sessionObservation = Task { [weak self] in
                for await projection in await client.projections() {
                    guard !Task.isCancelled, let self, self.generation == token else { return }
                    self.projection = projection
                }
            }
        } catch {
            guard generation == token else { return }
            state = .failed((error as? PiError) ?? .transport(message: error.localizedDescription, outcomeUnknown: false))
            connection = nil
            await client.disconnect()
        }
    }

    func send() async {
        guard canSend, let connection else { return }
        let token = generation
        let submitted = draft
        isSending = true; actionError = nil
        do {
            try await connection.send(submitted)
            guard generation == token else { return }
            if draft == submitted { draft = "" }
        } catch {
            guard generation == token else { return }
            actionError = error.localizedDescription
            if let error = error as? PiError, error.isOutcomeUnknown { state = .failed(error) }
        }
        if generation == token { isSending = false }
    }

    func stop() async {
        guard canStop, let connection else { return }
        let token = generation
        isStopping = true; actionError = nil
        do { try await connection.stop() }
        catch {
            guard generation == token else { return }
            actionError = error.localizedDescription
            if let error = error as? PiError, error.isOutcomeUnknown { state = .failed(error) }
        }
        if generation == token { isStopping = false }
    }

    func disconnect() async {
        let mayContinue = requiresDisconnectWarning
        let pendingRequest = isSending || isStopping
        let wasConnecting = state == .connecting
        generation = UUID()
        observation?.cancel(); observation = nil
        sessionObservation?.cancel(); sessionObservation = nil
        let previous = connection
        connection = nil
        if pendingRequest { actionError = "Request outcome unknown after disconnect. Server work may continue; nothing will be resent automatically." }
        else if mayContinue { actionError = "Disconnected. Server work may continue; this did not stop or close the session." }
        else if wasConnecting { actionError = "Disconnected during setup. A demo runtime may have been created on the server." }
        isSending = false; isStopping = false; state = .disconnected
        await previous?.disconnect()
    }

    deinit {
        observation?.cancel(); sessionObservation?.cancel()
        let client = connection
        Task { await client?.disconnect() }
    }
}
