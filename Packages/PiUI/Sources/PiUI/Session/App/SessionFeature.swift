import Foundation
import Flux
import PiSDK

/// The conversation: transcript, send/stop admission and prompt errors for the session the
/// workspace has attached. It does not browse, open, connect or disconnect — `WorkspaceFeature`
/// owns the server and the open tabs, and publishes the connection through `SessionTransport`.
public struct SessionFeature: Feature {
    public struct State: Equatable, Sendable {
        public internal(set) var connection: PiConnectionState = .disconnected
        public internal(set) var projection: DemoSessionProjection?
        /// Set once a send is admitted, so the workspace can drop the matching per-tab draft.
        public internal(set) var clearDraftMatching: String?
        public internal(set) var isSending = false
        public internal(set) var isStopping = false
        public internal(set) var actionError: String?
        /// The runtime this conversation expects to observe. A projection for any other runtime
        /// belongs to a switch that has been superseded and must not be rendered.
        public internal(set) var observedSessionId: String?
        internal var generation = UUID()
        internal var attachRequest: UUID?
        internal var sendRequest: UUID?
        internal var stopRequest: UUID?

        public init() {}

        public var canEditMessage: Bool {
            guard case .ready = connection else { return false }
            return projection?.status == .idle && !isSending && !isStopping
        }
        public var canSend: Bool { canEditMessage }
        public var canStop: Bool {
            guard case .ready = connection else { return false }
            return projection?.status == .running && !isSending && !isStopping
        }
        public var statusText: String {
            switch connection {
            case .disconnected: return "Disconnected"
            case .connecting: return "Attaching…"
            case .connected: return "Connected"
            case .failed(let error): return error.isOutcomeUnknown ? "Outcome unknown" : "Connection failed"
            case .ready:
                if isStopping || projection?.status == .aborting { return "Stopping…" }
                if isSending || projection?.status == .starting || projection?.status == .running { return "Generating…" }
                return "Ready"
            }
        }
        public var errorMessage: String? {
            if case .failed(let error) = connection { return error.localizedDescription }
            return actionError ?? projection?.error
        }
        public var requiresDisconnectWarning: Bool {
            isSending || isStopping || (projection != nil && projection?.status != .idle)
        }
    }

    public enum Action: Equatable, Sendable {
        /// The workspace attached this runtime: observe its transcript only.
        case attachRequested(UUID = UUID(), sessionId: String)
        /// The workspace has no observed runtime: stop showing a conversation.
        case detachRequested(UUID = UUID())
        case attached(UUID, DemoSession)
        case projectionChanged(UUID, DemoSessionProjection)
        case clearDraftConsumed
        case sendRequested(UUID = UUID(), text: String)
        case stopRequested(UUID = UUID())
        case sendFinished(UUID, submitted: String, error: PiError?)
        case stopFinished(UUID, error: PiError?)
        /// A transport failure the conversation can see, reported by its own request.
        case failed(UUID, PiError)
    }

    public init() {}

    @MainActor public func reduce(_ state: inout State, _ action: Action) {
        switch action {
        case .attachRequested(let request, let sessionId):
            state.attachRequest = request
            guard state.observedSessionId != sessionId else { return }
            // A different runtime invalidates in-flight work: its results belong to the old one.
            state.observedSessionId = sessionId
            state.generation = UUID()
            state.connection = .connecting
            state.projection = nil
            state.actionError = nil
            state.clearDraftMatching = nil
            state.isSending = false; state.isStopping = false
            state.sendRequest = nil; state.stopRequest = nil
        case .detachRequested:
            state = .init()
        case .attached(let token, let session):
            guard state.generation == token else { return }
            state.connection = .ready(session)
        case .projectionChanged(let token, let projection):
            guard state.generation == token else { return }
            state.projection = projection
        case .clearDraftConsumed: state.clearDraftMatching = nil
        case .sendRequested(let request, let text):
            guard state.canSend, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            state.sendRequest = request
            state.isSending = true; state.actionError = nil; state.clearDraftMatching = nil
        case .sendFinished(let token, let submitted, let error):
            guard state.generation == token else { return }
            if let error {
                state.actionError = error.localizedDescription
                if error.isOutcomeUnknown { state.connection = .failed(error) }
            } else { state.clearDraftMatching = submitted }
            state.isSending = false; state.sendRequest = nil
        case .stopRequested(let request):
            guard state.canStop else { return }
            state.stopRequest = request
            state.isStopping = true; state.actionError = nil
        case .stopFinished(let token, let error):
            guard state.generation == token else { return }
            if let error {
                state.actionError = error.localizedDescription
                if error.isOutcomeUnknown { state.connection = .failed(error) }
            }
            state.isStopping = false; state.stopRequest = nil
        case .failed(let token, let error):
            guard state.generation == token else { return }
            state.connection = .failed(error)
        }
    }
}
