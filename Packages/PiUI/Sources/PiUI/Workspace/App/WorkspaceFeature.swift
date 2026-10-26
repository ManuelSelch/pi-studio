import Foundation
import Flux
import PiSDK

/// Navigation and transport: the connection, the catalogue, the ordered open sessions and the
/// tab-level local state. It owns no transcript; the conversation lives in `SessionFeature`,
/// which observes the runtime this store reports as `observedRuntimeId`.
public struct WorkspaceFeature: Feature {
    public struct State: Equatable, Sendable {
        public internal(set) var connection: PiConnectionState = .disconnected
        public internal(set) var catalogue = PiCatalogue()
        /// Ordered tabs, kept separate from the catalogue and the runtime inventory.
        public internal(set) var openSessions: [OpenSession] = []
        /// The selected tab. It can be empty while tabs stay open (iPhone browsing).
        public internal(set) var selectedSessionId: String?
        /// The runtime the middleware has actually attached, so the conversation subscribes to
        /// the session the SDK is observing rather than to a selection still in flight.
        public internal(set) var observedRuntimeId: String?
        public internal(set) var isOpening = false
        public internal(set) var isDisconnecting = false
        public internal(set) var error: String?
        internal var unknownOutcome = false
        internal var generation = UUID()
        internal var connectRequest: UUID?
        internal var openRequest: UUID?
        internal var selectRequest: UUID?
        internal var disconnectRequest: UUID?

        public init() {}

        public var isConnected: Bool {
            return switch connection { case .connected, .ready: true; default: false }
        }
        public var canConnect: Bool {
            guard !isDisconnecting else { return false }
            return switch connection { case .disconnected, .failed: true; default: false }
        }
        public var canOpen: Bool { isConnected && !isOpening && !unknownOutcome }
        public var openSessionIds: [String] { openSessions.map(\.id) }
        public var selectedSession: OpenSession? {
            selectedSessionId.flatMap { id in openSessions.first { $0.id == id } }
        }
        public func session(id: String) -> OpenSession? { openSessions.first { $0.id == id } }
        /// The tab a browsing target already maps to, if the user opened it before.
        public func existingTab(for target: ProjectSessionTarget) -> OpenSession? {
            switch target {
            case .runtime(let id): openSessions.first { $0.runtimeId == id }
            case .history(let path): openSessions.first { $0.sessionPath == path }
            }
        }
        /// A disconnect would lose work that is still running on the server.
        public var requiresDisconnectWarning: Bool {
            isOpening || catalogue.sessions.contains { ["running", "blocked"].contains($0.status) }
        }
        public var status: String {
            if isDisconnecting { return "Disconnecting…" }
            switch connection {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting…"
            case .failed(let error): return error.isOutcomeUnknown ? "Outcome unknown" : "Connection failed"
            case .connected, .ready: return isOpening ? "Opening…" : "Connected"
            }
        }
        /// Draft text of the selected tab, the source of the composer's text.
        public var draft: String { selectedSession?.draft ?? "" }
        public var followTail: Bool { selectedSession?.followTail ?? true }
        public var scrollAnchor: String? { selectedSession?.scrollAnchor }

        /// Authoritative run status for every open tab, from the server inventory.
        mutating func refreshActivity() {
            for index in openSessions.indices {
                openSessions[index].activity = catalogue.sessions
                    .first { $0.sessionId == openSessions[index].runtimeId }
                    .flatMap { SessionActivity(runtimeStatus: $0.status) }
            }
        }

        /// Removing a selected tab moves to the neighbour on the right, else the left.
        mutating func close(_ id: String) {
            guard let index = openSessions.firstIndex(where: { $0.id == id }) else { return }
            let wasSelected = selectedSessionId == id
            openSessions.remove(at: index)
            guard wasSelected else { return }
            guard !openSessions.isEmpty else { selectedSessionId = nil; return }
            selectedSessionId = openSessions[min(index, openSessions.count - 1)].id
        }
    }

    public enum Action: Equatable, Sendable {
        case connectRequested(UUID = UUID(), takingControl: Bool)
        case connected(UUID)
        case connectionChanged(UUID, PiConnectionState)
        case catalogueChanged(UUID, PiCatalogue)
        case disconnectRequested(UUID = UUID())
        case disconnected(UUID)
        /// Resolve a browsing target into an open tab.
        case openRequested(UUID = UUID(), target: ProjectSessionTarget, title: String)
        case createRequested(UUID = UUID(), projectPath: String, title: String)
        /// Explicit open: the middleware resolved an identity, title and activity.
        case opened(UUID, OpenSession)
        case selectRequested(UUID = UUID(), id: String)
        case closeSession(String)
        /// The server ended this runtime: the tab cannot be reopened.
        case sessionClosed(String)
        case sessionReplaced(String, String)
        case observedRuntimeChanged(UUID, String?)
        case failed(UUID, PiError)
        case back
        case draftChanged(String)
        /// A send was admitted, so the matching per-tab draft can be dropped.
        case draftCleared(matching: String)
        case followTailChanged(Bool)
        case scrollAnchorChanged(String?)
        case unreadChanged(String, Bool)
    }

    public init() {}

    @MainActor public func reduce(_ state: inout State, _ action: Action) {
        switch action {
        case .connectRequested(let request, let takingControl):
            guard takingControl, state.canConnect else { return }
            state = .init(); state.connectRequest = request; state.connection = .connecting
        case .connected(let token):
            guard token == state.generation else { return }
            state.connection = .connected
        case .connectionChanged(let token, let value):
            guard token == state.generation else { return }
            state.connection = value
            if case .failed(let error) = value { state.error = error.localizedDescription; state.isOpening = false }
        case .catalogueChanged(let token, let catalogue):
            guard token == state.generation else { return }
            state.catalogue = catalogue
            state.refreshActivity()
        case .disconnectRequested(let request):
            guard state.disconnectRequest != request else { return }
            state.disconnectRequest = request
            state.observedRuntimeId = nil
            state.isOpening = false
            state.isDisconnecting = true
        case .disconnected(let token):
            state.generation = token
            state.connection = .disconnected
            state.observedRuntimeId = nil
            state.isOpening = false
            state.isDisconnecting = false
        case .openRequested(let request, _, _), .createRequested(let request, _, _):
            guard state.canOpen, state.openRequest != request else { return }
            state.openRequest = request
            state.isOpening = true; state.error = nil
        case .opened(let token, let session):
            guard token == state.generation else { return }
            state.isOpening = false
            // The same history or runtime selects its existing tab instead of a duplicate.
            if let existing = state.openSessions.first(where: { $0.matches(session.identity) }) {
                state.selectedSessionId = existing.id
                return
            }
            // Tabs keep their order: a new session is appended, never inserted.
            state.openSessions.append(session)
            state.selectedSessionId = session.id
        case .selectRequested(let request, let id):
            guard state.openSessions.contains(where: { $0.id == id }), state.selectRequest != request else { return }
            state.selectRequest = request
            state.selectedSessionId = id
        case .closeSession(let id):
            state.close(id)
        case .sessionClosed(let id):
            state.close(id)
        case .sessionReplaced(let id, let runtimeId):
            guard let index = state.openSessions.firstIndex(where: { $0.id == id }) else { return }
            state.openSessions[index].runtimeId = runtimeId
            state.refreshActivity()
        case .observedRuntimeChanged(let token, let runtimeId):
            guard token == state.generation else { return }
            state.observedRuntimeId = runtimeId
        case .failed(let token, let error):
            guard token == state.generation else { return }
            state.error = error.localizedDescription; state.isOpening = false
            // A failed connection attempt is a connection state; a failed open is not.
            if case .connecting = state.connection { state.connection = .failed(error) }
            if error.isOutcomeUnknown { state.unknownOutcome = true }
        case .back:
            guard !state.isOpening else { return }
            state.selectedSessionId = nil; state.error = nil
        case .draftChanged(let draft):
            guard let index = state.openSessions.firstIndex(where: { $0.id == state.selectedSessionId }) else { return }
            state.openSessions[index].draft = draft
        case .draftCleared(let matching):
            guard let index = state.openSessions.firstIndex(where: { $0.id == state.selectedSessionId }) else { return }
            guard state.openSessions[index].draft == matching else { return }
            state.openSessions[index].draft = ""
        case .followTailChanged(let follow):
            guard let index = state.openSessions.firstIndex(where: { $0.id == state.selectedSessionId }) else { return }
            state.openSessions[index].followTail = follow
        case .scrollAnchorChanged(let anchor):
            guard let index = state.openSessions.firstIndex(where: { $0.id == state.selectedSessionId }) else { return }
            state.openSessions[index].scrollAnchor = anchor
        case .unreadChanged(let id, let unread):
            guard let index = state.openSessions.firstIndex(where: { $0.id == id }) else { return }
            state.openSessions[index].unread = unread
        }
    }
}
