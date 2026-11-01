import Foundation
import Flux
import PiSDK

/// Owns the workspace's SDK effects: one connection, the catalogue and inventory streams, and
/// explicit open/attach/close. It never mutates state directly — every result is an action —
/// and it publishes the connection through `SessionTransport` for the conversation.
///
/// Selection work is serialized. A switch is allowed while another session runs, and an attach
/// whose choice was superseded is discarded and followed by another attempt, so the observed
/// runtime always converges on the selected tab.
@MainActor
public final class WorkspaceMiddleware: Middleware {
    public typealias F = WorkspaceFeature

    private let transport: SessionTransport
    /// The conversation follows the runtime this middleware attaches. Flux 2 has no cross-store
    /// dispatch, so the workspace — which owns the transport — tells it what it is observing.
    private let sessionStore: FluxStore<SessionFeature>

    private let endpointProvider: @MainActor () -> URL
    private let laterSessions: any LaterSessionsService
    private let makeConnection: @Sendable (URL) -> any PiSessionConnection
    private var connectionEndpoint: URL?

    private var store: StoreHandle<WorkspaceFeature>?
    private var connection: (any PiSessionConnection)?
    private var connectionGeneration: UUID?
    private var connecting: Task<Void, Never>?
    private var catalogueObservation: Task<Void, Never>?
    private var stateObservation: Task<Void, Never>?
    private var eventObservation: Task<Void, Never>?
    private var connectingRequest: UUID?
    private var disconnectRequest: UUID?
    private var openRequest: UUID?

    /// The tab whose runtime the connection currently observes.
    private var observedKey: String?
    /// Serializes selection work so an in-flight attach cannot land on a later choice.
    private var selectionLoop: Task<Void, Never>?

    public init(transport: SessionTransport, sessionStore: FluxStore<SessionFeature>,
                endpointProvider: @escaping @MainActor () -> URL,
                laterSessions: any LaterSessionsService,
                makeConnection: @escaping @Sendable (URL) -> any PiSessionConnection) {
        self.transport = transport
        self.sessionStore = sessionStore
        self.endpointProvider = endpointProvider
        self.laterSessions = laterSessions
        self.makeConnection = makeConnection
    }

    public func initialize(_ store: StoreHandle<WorkspaceFeature>) { self.store = store }

    public func handle(_ state: WorkspaceFeature.State, _ action: WorkspaceFeature.Action) async -> WorkspaceFeature.Action? {
        guard let store else { return nil }
        switch action {
        case .connectRequested(let request, _):
            guard state.connectRequest == request, store.getState()?.connectRequest == request,
                  connectingRequest != request else { return nil }
            connectingRequest = request
            beginConnect(token: state.generation, store: store)
        case .disconnectRequested(let request):
            guard state.disconnectRequest == request, store.getState()?.disconnectRequest == request,
                  disconnectRequest != request else { return nil }
            disconnectRequest = request
            let token = state.generation
            cancelSelection()
            let pending = [connecting, catalogueObservation, stateObservation, eventObservation]
            connecting = nil; catalogueObservation = nil; stateObservation = nil; eventObservation = nil
            let previous = connection
            connection = nil; connectionGeneration = nil
            transport.publish(nil)
            sessionStore.dispatch(.detachRequested())
            await previous?.disconnect()
            for task in pending { await task?.value }
            disconnectRequest = nil
            guard store.getState()?.generation == token else { return nil }
            return .disconnected(UUID())
        case .openRequested(let request, let target, let title):
            guard state.openRequest == request, store.getState()?.openRequest == request,
                  openRequest != request else { return nil }
            openRequest = request
            let parkedPath = laterPath(for: target, in: state)
            // Already open: select that tab instead of asking the server again.
            if let existing = store.getState()?.existingTab(for: target) {
                if let parkedPath { removeFromLater(parkedPath, state: state, store: store) }
                return .opened(state.generation, existing)
            }
            guard let connection else { return nil }
            let token = state.generation
            let opened: DemoSession?
            let failure: PiError?
            do {
                switch target {
                case .runtime(let id): opened = try await connection.attachSession(sessionId: id)
                case .history(let path): opened = try await connection.openSession(sessionPath: path)
                }
                failure = nil
            } catch let error {
                opened = nil; failure = Self.normalize(error)
            }
            guard let live = store.getState(), live.generation == token, live.openRequest == request else { return nil }
            guard let opened else { return .failed(token, failure ?? .invalidState) }
            if let parkedPath { removeFromLater(parkedPath, state: live, store: store) }
            let tab = tab(for: opened, title: title, requested: target, in: live)
            // The open response already observed this runtime: adopt it without a second attach.
            observedKey = tab.id
            return .opened(token, tab)
        case .archiveRequested(let path):
            guard let connection, state.canOpen, !path.isEmpty else { return nil }
            do {
                try await connection.archiveSession(path: path)
                guard store.getState()?.generation == state.generation else { return nil }
                return .archived(path: path)
            } catch {
                guard store.getState()?.generation == state.generation else { return nil }
                let failure = Self.normalize(error)
                return .archiveFailed(error: failure.localizedDescription, outcomeUnknown: failure.isOutcomeUnknown)
            }
        case .moveToLaterRequested(let path):
            await moveToLater(path: path, state: state, store: store)
        case .catalogueChanged:
            reconcileLater(state: state, store: store)
        case .createRequested(let request, let projectPath, let title):
            guard state.openRequest == request, store.getState()?.openRequest == request,
                  openRequest != request, let connection else { return nil }
            openRequest = request
            let token = state.generation
            let created: DemoSession?
            let failure: PiError?
            do { created = try await connection.createSession(projectPath: projectPath); failure = nil }
            catch let error { created = nil; failure = Self.normalize(error) }
            guard let live = store.getState(), live.generation == token, live.openRequest == request else { return nil }
            guard let created else { return .failed(token, failure ?? .invalidState) }
            let tab = OpenSession(identity: OpenSessionIdentity(scope: endpointString, sessionPath: nil,
                                                               runtimeId: created.sessionId,
                                                               projectPath: created.projectPath),
                                  title: title, activity: activity(for: created.sessionId, in: live))
            observedKey = tab.id
            return .opened(token, tab)
        case .selectRequested, .closeSession, .movedToLater, .archived, .sessionClosed, .sessionReplaced, .opened, .failed:
            // Selection changed: make the observed runtime match the selected tab.
            enqueueSelection()
        default:
            break
        }
        return nil
    }

    // MARK: - Connection

    private func beginConnect(token: UUID, store: StoreHandle<WorkspaceFeature>) {
        cancelSelection()
        let pending = [connecting, catalogueObservation, stateObservation, eventObservation]
        connecting = nil; catalogueObservation = nil; stateObservation = nil; eventObservation = nil
        let previous = connection
        let endpoint = endpointProvider()
        connectionEndpoint = endpoint
        store.dispatch(.laterLoaded(laterSessions.load(endpoint: endpoint)))
        let client = makeConnection(endpoint)
        connection = client; connectionGeneration = token
        transport.publish(client)
        connecting = Task {
            await previous?.disconnect()
            for task in pending { await task?.value }
            guard !Task.isCancelled, store.getState()?.generation == token else {
                await client.disconnect()
                return
            }
            do {
                try await client.connect(takingControl: true)
                guard !Task.isCancelled, store.getState()?.generation == token else {
                    await client.disconnect()
                    return
                }
                store.dispatch(.connected(token))
                observe(client, token: token, store: store)
            } catch {
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                discardConnection(token: token)
                await client.disconnect()
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                store.dispatch(.failed(token, Self.normalize(error)))
            }
        }
    }

    private func observe(_ client: any PiSessionConnection, token: UUID, store: StoreHandle<WorkspaceFeature>) {
        catalogueObservation = Task {
            for await catalogue in await client.catalogues() {
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                store.dispatch(.catalogueChanged(token, catalogue))
            }
        }
        stateObservation = Task {
            for await value in await client.states() {
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                store.dispatch(.connectionChanged(token, value))
            }
        }
        eventObservation = Task {
            for await event in await client.sessionEvents() {
                guard !Task.isCancelled, let live = store.getState(), live.generation == token else { return }
                switch event {
                case .closed(let sessionId):
                    guard let tab = live.openSessions.first(where: { $0.runtimeId == sessionId }) else { continue }
                    if self.observedKey == tab.id { self.observedKey = nil }
                    store.dispatch(.sessionClosed(tab.id))
                    self.enqueueSelection()
                case .replaced(let previous, let current):
                    guard let tab = live.openSessions.first(where: { $0.runtimeId == previous.sessionId }) else { continue }
                    store.dispatch(.sessionReplaced(tab.id, current.sessionId))
                    if self.observedKey == tab.id {
                        // The work moved to a new identity: keep observing it under the same tab.
                        self.observedKey = nil
                        self.sessionStore.dispatch(.attachRequested(sessionId: current.sessionId))
                        self.observedKey = tab.id
                    }
                }
            }
        }
    }

    private func discardConnection(token: UUID) {
        guard connectionGeneration == token else { return }
        connection = nil; connectionGeneration = nil
        transport.publish(nil)
    }

    // MARK: - Selection

    private func enqueueSelection() {
        guard selectionLoop == nil else { return }
        selectionLoop = Task { [weak self] in
            await self?.drainSelection()
            guard let self else { return }
            self.selectionLoop = nil
            if self.needsSelection { self.enqueueSelection() }
        }
    }

    private var needsSelection: Bool {
        guard let store else { return false }
        return store.getState()?.observedRuntimeId != store.getState()?.selectedSession?.runtimeId
    }

    private func cancelSelection() {
        selectionLoop?.cancel(); selectionLoop = nil
        observedKey = nil
    }

    /// Attaches until the observed runtime is the selected one; a superseded result is dropped.
    private func drainSelection() async {
        while true {
            guard let store, let live = store.getState(), let connection else { return }
            guard let tab = live.selectedSession else {
                observedKey = nil
                store.dispatch(.observedRuntimeChanged(live.generation, nil))
                sessionStore.dispatch(.detachRequested())
                return
            }
            if observedKey == tab.id {
                // Already attached (an open response observes its own runtime): publish it and
                // hand the conversation its transcript.
                store.dispatch(.observedRuntimeChanged(live.generation, tab.runtimeId))
                sessionStore.dispatch(.attachRequested(sessionId: tab.runtimeId))
                return
            }
            let token = live.generation
            do {
                let attached = try await connection.attachSession(sessionId: tab.runtimeId)
                guard !Task.isCancelled, let now = store.getState(), now.generation == token else { return }
                // A newer selection won while this request was in flight: try again for it.
                guard now.selectedSession?.id == tab.id else { continue }
                observedKey = tab.id
                store.dispatch(.observedRuntimeChanged(token, attached.sessionId))
                sessionStore.dispatch(.attachRequested(sessionId: attached.sessionId))
            } catch {
                guard !Task.isCancelled, let now = store.getState(), now.generation == token else { return }
                guard now.selectedSession?.id == tab.id else { continue }
                observedKey = nil
                store.dispatch(.failed(token, Self.normalize(error)))
                store.dispatch(.observedRuntimeChanged(token, nil))
                return
            }
            return
        }
    }

    // MARK: - Later

    private func moveToLater(path: String, state: WorkspaceFeature.State, store: StoreHandle<WorkspaceFeature>) async {
        guard let endpoint = connectionEndpoint, let connection,
              SessionInboxModel.sessions(state.catalogue, laterPaths: state.laterSessionPaths)
                .contains(where: { $0.row.sessionPath == path && $0.canMoveLater }) else { return }
        let runtime = state.catalogue.sessions.first(where: { $0.sessionPath == path })
        guard runtime == nil || runtime?.status == "idle" else { return }
        var paths = state.laterSessionPaths
        paths.insert(path)
        laterSessions.save(paths, endpoint: endpoint)
        if let runtime {
            do { try await connection.closeSession(sessionId: runtime.sessionId) }
            catch {
                let outcomeUnknown = (error as? PiError)?.isOutcomeUnknown ?? true
                if !outcomeUnknown {
                    paths.remove(path)
                    laterSessions.save(paths, endpoint: endpoint)
                }
                store.dispatch(.moveToLaterFailed(path: path, error: error.localizedDescription,
                                                  outcomeUnknown: outcomeUnknown))
                return
            }
        }
        guard store.getState()?.generation == state.generation else { return }
        store.dispatch(.movedToLater(path: path))
    }

    private func reconcileLater(state: WorkspaceFeature.State, store: StoreHandle<WorkspaceFeature>) {
        guard state.catalogue.projectRevision > 0, let endpoint = connectionEndpoint else { return }
        let knownPaths = Set(state.catalogue.projects.flatMap { $0.sessions.filter { $0.archivedAt == nil }.map(\.path) })
        let retained = state.laterSessionPaths.intersection(knownPaths)
        guard retained != state.laterSessionPaths else { return }
        laterSessions.save(retained, endpoint: endpoint)
        store.dispatch(.laterLoaded(retained))
    }

    private func removeFromLater(_ path: String, state: WorkspaceFeature.State, store: StoreHandle<WorkspaceFeature>) {
        guard state.laterSessionPaths.contains(path), let endpoint = connectionEndpoint else { return }
        var paths = state.laterSessionPaths
        paths.remove(path)
        laterSessions.save(paths, endpoint: endpoint)
        store.dispatch(.laterResumed(path: path))
    }

    private func laterPath(for target: ProjectSessionTarget, in state: WorkspaceFeature.State) -> String? {
        switch target {
        case .history(let path): state.laterSessionPaths.contains(path) ? path : nil
        case .runtime(let id):
            state.catalogue.sessions.first { $0.sessionId == id }?.sessionPath.flatMap {
                state.laterSessionPaths.contains($0) ? $0 : nil
            }
        }
    }

    // MARK: - Helpers

    private var endpointString: String { (connectionEndpoint ?? endpointProvider()).absoluteString }

    private func tab(for session: DemoSession, title: String, requested: ProjectSessionTarget,
                     in state: WorkspaceFeature.State) -> OpenSession {
        var path: String?
        if case .history(let requestedPath) = requested { path = requestedPath }
        else { path = state.catalogue.sessions.first { $0.sessionId == session.sessionId }?.sessionPath }
        let identity = OpenSessionIdentity(scope: endpointString, sessionPath: path,
                                           runtimeId: session.sessionId, projectPath: session.projectPath)
        let existing = state.openSessions.first { $0.matches(identity) }
        var tab = OpenSession(identity: identity, title: existing?.title ?? title,
                              activity: activity(for: session.sessionId, in: state))
        tab.followTail = existing?.followTail ?? true
        tab.scrollAnchor = existing?.scrollAnchor
        tab.unread = existing?.unread ?? false
        return tab
    }

    private func activity(for runtimeId: String, in state: WorkspaceFeature.State) -> SessionActivity? {
        state.catalogue.sessions.first { $0.sessionId == runtimeId }
            .flatMap { SessionActivity(runtimeStatus: $0.status) }
    }

    private static func normalize(_ error: Error) -> PiError {
        (error as? PiError) ?? .transport(message: error.localizedDescription, outcomeUnknown: false)
    }

    deinit {
        connecting?.cancel(); catalogueObservation?.cancel()
        stateObservation?.cancel(); eventObservation?.cancel()
        selectionLoop?.cancel()
        let client = connection
        Task { await client?.disconnect() }
    }
}
