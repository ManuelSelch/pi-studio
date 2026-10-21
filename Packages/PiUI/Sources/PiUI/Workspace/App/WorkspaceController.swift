import Foundation
import Flux
import PiSDK

/// Owns browsing and explicit navigation, not protocol state or a new scheduler.
@MainActor public final class WorkspaceController {
    public let store = FluxStore<WorkspaceFeature>(state: .init())
    public let session: SessionController
    public var state: WorkspaceFeature.State { store.state }
    private let makeConnection: @Sendable (URL) -> any PiSessionConnection
    private var connection: (any PiSessionConnection)?
    private var observation: Task<Void, Never>?
    private var catalogueObservation: Task<Void, Never>?
    private var drafts: [String: String] = [:]
    public init(session: SessionController, makeConnection: @escaping @Sendable (URL) -> any PiSessionConnection = { PiClient(endpoint: $0) }) {
        self.session = session; self.makeConnection = makeConnection
    }
    public var canNavigate: Bool {
        !state.isOpening && !session.state.isSending && !session.state.isStopping
            && session.state.projection?.status != .starting && session.state.projection?.status != .aborting
    }
    public var requiresDisconnectWarning: Bool {
        state.isOpening || session.state.requiresDisconnectWarning || state.catalogue.sessions.contains { ["running", "blocked"].contains($0.status) }
    }

    public func connect(takingControl: Bool) async {
        guard takingControl, state.canConnect else { return }
        let token = UUID()
        observation?.cancel(); catalogueObservation?.cancel()
        store.dispatch(.connecting(token)); drafts = [:]
        let previous = connection; connection = nil
        await previous?.disconnect()
        await session.disconnect()
        guard state.generation == token else { return }
        let client = makeConnection(session.configuration.endpoint); connection = client
        do {
            try await client.connect(takingControl: true)
            guard state.generation == token else { return }
            store.dispatch(.connectionChanged(token, .connected))
            // Register before returning so cold catalogue updates cannot be missed.
            let catalogues = await client.catalogues()
            let states = await client.states()
            catalogueObservation = Task { [weak self] in
                for await value in catalogues {
                    guard !Task.isCancelled, let self else { return }
                    self.store.dispatch(.catalogueChanged(token, value))
                }
            }
            observation = Task { [weak self] in
                for await value in states {
                    guard !Task.isCancelled, let self else { return }
                    self.store.dispatch(.connectionChanged(token, value))
                }
            }
        } catch {
            guard state.generation == token else { return }
            store.dispatch(.connectionChanged(token, .failed(normalize(error))))
            connection = nil; await client.disconnect()
        }
    }
    public func open(_ target: ProjectSessionTarget, title: String) async {
        await select(title: title) { client in
            switch target {
            case .runtime(let id): try await client.attachSession(sessionId: id)
            case .history(let path): try await client.openSession(sessionPath: path)
            }
        }
    }
    public func createSession(projectPath: String) async {
        let quick = state.catalogue.projects.first { $0.path == projectPath }?.quickChats == true
        await select(title: quick ? "New chat" : "New session") { try await $0.createSession(projectPath: projectPath) }
    }
    private func select(title: String, operation: (any PiSessionConnection) async throws -> DemoSession) async {
        guard state.canOpen, canNavigate, let connection else { return }
        let token = state.generation
        saveDraft()
        store.dispatch(.opening)
        do {
            let selected = try await operation(connection)
            guard state.generation == token else { return }
            session.attach(connection: connection, session: selected)
            session.setDraft(drafts[selected.sessionId] ?? "")
            store.dispatch(.opened(token, selected, title))
        } catch {
            store.dispatch(.failed(token, normalize(error)))
        }
    }
    private func saveDraft() {
        if case .ready(let selected) = session.state.connection { drafts[selected.sessionId] = session.state.draft }
    }
    public func back() { guard canNavigate else { return }; saveDraft(); store.dispatch(.back) }
    public func disconnect() async {
        observation?.cancel(); observation = nil
        catalogueObservation?.cancel(); catalogueObservation = nil
        let previous = connection; connection = nil
        store.dispatch(.disconnected(UUID()))
        await session.disconnect()
        await previous?.disconnect()
    }
    private func normalize(_ error: Error) -> PiError { (error as? PiError) ?? .transport(message: error.localizedDescription, outcomeUnknown: false) }
    deinit {
        observation?.cancel(); catalogueObservation?.cancel()
        let connection = connection
        Task { await connection?.disconnect() }
    }
}
