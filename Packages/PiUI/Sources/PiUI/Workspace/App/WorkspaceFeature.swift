import Foundation
import Flux
import PiSDK

/// The workspace store: connection, catalogue, navigation and the ordered open
/// sessions. It owns no transcript; PiSDK stays authoritative for session content.
public struct WorkspaceFeature: Feature {
    public struct State: Equatable, Sendable {
        public internal(set) var connection: PiConnectionState = .disconnected
        public internal(set) var catalogue = PiCatalogue()
        /// Ordered tabs, kept separate from the catalogue and the runtime inventory.
        public internal(set) var openSessions: [OpenSession] = []
        /// The selected tab. It can be empty while tabs stay open (iPhone browsing).
        public internal(set) var selectedSessionId: String?
        public internal(set) var isOpening = false
        public internal(set) var error: String?
        internal var unknownOutcome = false
        internal var generation = UUID()

        public init() {}

        public var isConnected: Bool {
            switch connection { case .connected, .ready: true; default: false }
        }
        public var canConnect: Bool {
            switch connection { case .disconnected, .failed: true; default: false }
        }
        public var canOpen: Bool { isConnected && !isOpening && !unknownOutcome }
        public var openSessionIds: [String] { openSessions.map(\.id) }
        public var selectedSession: OpenSession? {
            selectedSessionId.flatMap { id in openSessions.first { $0.id == id } }
        }
        public func session(id: String) -> OpenSession? { openSessions.first { $0.id == id } }
        public var status: String {
            switch connection {
            case .disconnected: "Disconnected"
            case .connecting: "Connecting…"
            case .failed(let error): error.isOutcomeUnknown ? "Outcome unknown" : "Connection failed"
            case .connected, .ready: isOpening ? "Opening…" : "Connected"
            }
        }

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
        case connecting(UUID)
        case connectionChanged(UUID, PiConnectionState)
        case catalogueChanged(UUID, PiCatalogue)
        case opening
        /// Explicit open: the controller resolved an identity and its title.
        case opened(UUID, OpenSession)
        case selectSession(String)
        case closeSession(String)
        /// The server ended this runtime: the tab cannot be reopened.
        case sessionClosed(String)
        case sessionReplaced(String, String)
        case sessionDraftChanged(String, String)
        case sessionFollowTailChanged(String, Bool)
        case sessionScrollAnchorChanged(String, String?)
        case sessionUnreadChanged(String, Bool)
        case failed(UUID, PiError)
        case back
        case disconnected(UUID)
    }

    public init() {}

    @MainActor public func reduce(_ state: inout State, _ action: Action) {
        switch action {
        case .connecting(let token):
            guard state.canConnect else { return }
            state = .init(); state.generation = token; state.connection = .connecting
        case .connectionChanged(let token, let value):
            guard token == state.generation else { return }
            state.connection = value
            if case .failed(let error) = value { state.error = error.localizedDescription; state.isOpening = false }
        case .catalogueChanged(let token, let catalogue):
            guard token == state.generation else { return }
            state.catalogue = catalogue
            state.refreshActivity()
        case .opening:
            guard state.canOpen else { return }
            state.isOpening = true; state.error = nil
        case .opened(let token, let session):
            guard token == state.generation else { return }
            state.isOpening = false
            // The same history or runtime selects its existing tab instead of a duplicate.
            if let existing = state.openSessions.first(where: { $0.id == session.id || $0.runtimeId == session.runtimeId
                || ($0.sessionPath != nil && $0.sessionPath == session.sessionPath) }) {
                state.selectedSessionId = existing.id
                return
            }
            // Tabs keep their order: a new session is appended, never inserted.
            state.openSessions.append(session)
            state.selectedSessionId = session.id
        case .selectSession(let id):
            guard state.openSessions.contains(where: { $0.id == id }) else { return }
            state.selectedSessionId = id
        case .closeSession(let id):
            state.close(id)
        case .sessionClosed(let id):
            state.close(id)
        case .sessionReplaced(let id, let runtimeId):
            guard let index = state.openSessions.firstIndex(where: { $0.id == id }) else { return }
            state.openSessions[index].runtimeId = runtimeId
            state.refreshActivity()
        case .sessionDraftChanged(let id, let draft):
            guard let index = state.openSessions.firstIndex(where: { $0.id == id }) else { return }
            state.openSessions[index].draft = draft
        case .sessionFollowTailChanged(let id, let follow):
            guard let index = state.openSessions.firstIndex(where: { $0.id == id }) else { return }
            state.openSessions[index].followTail = follow
        case .sessionScrollAnchorChanged(let id, let anchor):
            guard let index = state.openSessions.firstIndex(where: { $0.id == id }) else { return }
            state.openSessions[index].scrollAnchor = anchor
        case .sessionUnreadChanged(let id, let unread):
            guard let index = state.openSessions.firstIndex(where: { $0.id == id }) else { return }
            state.openSessions[index].unread = unread
        case .failed(let token, let error):
            guard token == state.generation else { return }
            state.error = error.localizedDescription; state.isOpening = false
            if error.isOutcomeUnknown { state.unknownOutcome = true }
        case .back:
            guard !state.isOpening else { return }
            state.selectedSessionId = nil; state.error = nil
        case .disconnected(let token):
            state.generation = token; state.connection = .disconnected; state.isOpening = false
        }
    }
}
