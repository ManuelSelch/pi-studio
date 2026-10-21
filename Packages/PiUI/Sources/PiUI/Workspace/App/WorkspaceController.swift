import Foundation
import Flux
import PiSDK

/// The workspace coordinator: one connection, one catalogue, ordered open-session tabs
/// and the single live transcript the app shows. It is not a second observable model —
/// every UI-state change is a Flux action — and it never opens a socket per tab.
@MainActor public final class WorkspaceController {
    public let store = FluxStore<WorkspaceFeature>(state: .init())
    public let session: SessionController
    public var state: WorkspaceFeature.State { store.state }

    private let makeConnection: @Sendable (URL) -> any PiSessionConnection
    private var connection: (any PiSessionConnection)?
    private var observation: Task<Void, Never>?
    private var catalogueObservation: Task<Void, Never>?
    private var eventObservation: Task<Void, Never>?
    /// The tab whose runtime the conversation currently observes, if any.
    private var observedKey: String?
    /// Serializes selection work, so an in-flight attach can never land on a later choice.
    private var selectionLoop: Task<Void, Never>?
    private var pendingOpen: (() async -> Void)?

    public init(session: SessionController, makeConnection: @escaping @Sendable (URL) -> any PiSessionConnection = { PiClient(endpoint: $0) }) {
        self.session = session; self.makeConnection = makeConnection
    }

    /// Server scope for tab identity: sessions from another server never share a tab.
    private var scope: String { session.configuration.endpoint.absoluteString }

    public var canNavigate: Bool {
        !state.isOpening && !session.state.isSending && !session.state.isStopping
            && session.state.projection?.status != .starting && session.state.projection?.status != .aborting
    }
    public var requiresDisconnectWarning: Bool {
        state.isOpening || session.state.requiresDisconnectWarning || state.catalogue.sessions.contains { ["running", "blocked"].contains($0.status) }
    }

    // MARK: - Connection

    public func connect(takingControl: Bool) async {
        guard takingControl, state.canConnect else { return }
        let token = UUID()
        cancelObservations()
        store.dispatch(.connecting(token))
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
            let events = await client.sessionEvents()
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
            eventObservation = Task { [weak self] in
                for await event in events {
                    guard !Task.isCancelled, let self else { return }
                    self.apply(event, token: token)
                }
            }
        } catch {
            guard state.generation == token else { return }
            store.dispatch(.connectionChanged(token, .failed(normalize(error))))
            connection = nil; await client.disconnect()
        }
    }

    public func disconnect() async {
        cancelObservations()
        let previous = connection; connection = nil
        store.dispatch(.disconnected(UUID()))
        observedKey = nil
        await session.disconnect()
        await previous?.disconnect()
    }

    private func cancelObservations() {
        observation?.cancel(); observation = nil
        catalogueObservation?.cancel(); catalogueObservation = nil
        eventObservation?.cancel(); eventObservation = nil
        selectionLoop?.cancel(); selectionLoop = nil
        pendingOpen = nil
    }

    // MARK: - Opening and switching

    public func open(_ target: ProjectSessionTarget, title: String) async {
        await requestOpen(title: title, requested: target) { client in
            switch target {
            case .runtime(let id): try await client.attachSession(sessionId: id)
            case .history(let path): try await client.openSession(sessionPath: path)
            }
        }
    }
    public func createSession(projectPath: String) async {
        let quick = state.catalogue.projects.first { $0.path == projectPath }?.quickChats == true
        await requestOpen(title: quick ? "New chat" : "New session", requested: nil) {
            try await $0.createSession(projectPath: projectPath)
        }
    }

    /// Selection work runs one at a time; a switch during an in-flight request is not
    /// dropped, and its late result is discarded rather than rendered.
    private func requestOpen(title: String, requested: ProjectSessionTarget?,
                             operation: @escaping (any PiSessionConnection) async throws -> DemoSession) async {
        guard state.canOpen, connection != nil else { return }
        let work: () async -> Void = { [weak self] in
            guard let self else { return }
            await self.performOpen(title: title, requested: requested, operation: operation)
        }
        enqueueSelection(work)
        await drainSelectionLoop()
    }

    public func selectSession(id: String) async {
        guard state.openSessions.contains(where: { $0.id == id }) else { return }
        saveDraft()
        store.dispatch(.selectSession(id))
        enqueueSelection(nil)
        await drainSelectionLoop()
    }

    /// R8: local workspace action. It never aborts, closes or archives the runtime.
    public func closeSession(id: String) async {
        let wasSelected = state.selectedSessionId == id
        if wasSelected { saveDraft() }
        store.dispatch(.closeSession(id))
        guard wasSelected else { return }
        enqueueSelection(nil)
        await drainSelectionLoop()
    }

    public func back() {
        guard canNavigate else { return }
        saveDraft()
        store.dispatch(.back)
        startSelectionLoopIfNeeded()
    }

    public func setDraft(_ value: String) {
        session.setDraft(value)
        if let key = state.selectedSessionId { store.dispatch(.sessionDraftChanged(key, value)) }
    }

    private func performOpen(title: String, requested: ProjectSessionTarget?,
                             operation: (any PiSessionConnection) async throws -> DemoSession) async {
        guard state.canOpen, let connection else { return }
        let token = state.generation
        store.dispatch(.opening)
        do {
            let opened = try await operation(connection)
            guard state.generation == token else { return }
            let tab = openSession(title: title, kind: requested, opened: opened)
            store.dispatch(.opened(token, tab))
            // Only adopt what is still selected, and only once: the open response
            // already observed this runtime.
            guard state.selectedSessionId == tab.id else { return }
            session.attach(connection: connection, session: opened)
            session.setDraft(tab.draft)
            observedKey = tab.id
        } catch {
            guard state.generation == token else { return }
            store.dispatch(.failed(token, normalize(error)))
        }
    }

    private func openSession(title: String, kind: ProjectSessionTarget?, opened: DemoSession) -> OpenSession {
        var path: String?
        if case .history(let requested) = kind { path = requested }
        else { path = state.catalogue.sessions.first { $0.sessionId == opened.sessionId }?.sessionPath }
        let identity = OpenSessionIdentity(scope: scope, sessionPath: path,
                                           runtimeId: opened.sessionId, projectPath: opened.projectPath)
        // An existing tab keeps its own title, draft, order and read state.
        let existing = state.openSessions.first { $0.matches(identity) }
        var tab = OpenSession(identity: identity, title: existing?.title ?? title, activity: activity(for: opened.sessionId))
        tab.draft = existing?.draft ?? ""
        tab.followTail = existing?.followTail ?? true
        tab.unread = existing?.unread ?? false
        return tab
    }

    private func activity(for runtimeId: String) -> SessionActivity? {
        state.catalogue.sessions.first { $0.sessionId == runtimeId }.flatMap { SessionActivity(runtimeStatus: $0.status) }
    }

    // MARK: - Selection loop

    /// One loop at a time: an arriving choice is picked up by the running loop instead
    /// of starting a second in-flight selection request.
    private func enqueueSelection(_ work: (() async -> Void)?) {
        if let work { pendingOpen = work }
        guard selectionLoop == nil else { return }
        selectionLoop = Task { [weak self] in
            await self?.drainSelectionWork()
            guard let self else { return }
            self.selectionLoop = nil
            // Close the window between the last check and clearing the marker.
            if self.pendingOpen != nil || self.observedKey != self.state.selectedSessionId {
                self.startSelectionLoopIfNeeded()
            }
        }
    }

    private func startSelectionLoopIfNeeded() {
        guard selectionLoop == nil else { return }
        selectionLoop = Task { [weak self] in
            await self?.drainSelectionWork()
            guard let self else { return }
            self.selectionLoop = nil
        }
    }

    private func drainSelectionLoop() async {
        await selectionLoop?.value
    }

    /// Attaches until the observed runtime is the selected one, in order.
    private func drainSelectionWork() async {
        while true {
            if let open = pendingOpen {
                pendingOpen = nil
                await open()
                continue
            }
            guard let tab = state.selectedSession else {
                session.detach(); observedKey = nil
                if pendingOpen == nil { return }
                continue
            }
            if observedKey != tab.id {
                guard let connection else { return }
                let token = state.generation
                do {
                    let attached = try await connection.attachSession(sessionId: tab.runtimeId)
                    guard state.generation == token else { return }
                    // A newer selection won while this request was in flight.
                    guard state.selectedSessionId == tab.id else { continue }
                    session.attach(connection: connection, session: attached)
                    session.setDraft(tab.draft)
                    observedKey = tab.id
                } catch {
                    guard state.generation == token else { return }
                    guard state.selectedSessionId == tab.id else { continue }
                    store.dispatch(.failed(token, normalize(error)))
                    session.detach(); observedKey = nil
                    return
                }
            }
            if pendingOpen == nil && observedKey == state.selectedSessionId { return }
        }
    }

    /// The tab whose composer text is on screen owns it: a rapid switch must not copy
    /// one session's draft onto another.
    private func saveDraft() {
        guard let observedKey, observedKey == state.selectedSessionId else { return }
        guard case .ready = session.state.connection else { return }
        store.dispatch(.sessionDraftChanged(observedKey, session.state.draft))
    }

    // MARK: - Server identity events

    private func apply(_ event: PiSessionEvent, token: UUID) {
        guard state.generation == token else { return }
        switch event {
        case .closed(let sessionId):
            guard let tab = state.openSessions.first(where: { $0.runtimeId == sessionId }) else { return }
            if observedKey == tab.id { observedKey = nil }
            store.dispatch(.sessionClosed(tab.id))
            startSelectionLoopIfNeeded()
        case .replaced(let previous, let current):
            guard let tab = state.openSessions.first(where: { $0.runtimeId == previous.sessionId }) else { return }
            store.dispatch(.sessionReplaced(tab.id, current.sessionId))
        }
    }

    private func normalize(_ error: Error) -> PiError { (error as? PiError) ?? .transport(message: error.localizedDescription, outcomeUnknown: false) }

    deinit {
        observation?.cancel(); catalogueObservation?.cancel()
        eventObservation?.cancel(); selectionLoop?.cancel()
        let connection = connection
        Task { await connection?.disconnect() }
    }
}
