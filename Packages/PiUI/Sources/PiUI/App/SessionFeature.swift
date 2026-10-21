import Foundation
import Flux
import PiSDK

/// App-owned interaction state only. PiSDK remains authoritative for sessions.
public struct SessionFeature: Feature {
    public struct State: Equatable, Sendable {
        public internal(set) var connection: PiConnectionState = .disconnected
        public internal(set) var connectionEndpoint: URL?
        public internal(set) var projection: DemoSessionProjection?
        public internal(set) var clearDraftMatching: String?
        public internal(set) var isSending = false
        public internal(set) var isStopping = false
        public internal(set) var isDisconnecting = false
        public internal(set) var actionError: String?
        internal var generation = UUID()
        internal var sendRequest: UUID?
        internal var stopRequest: UUID?

        public init() {}

        public var canConnect: Bool {
            guard !isDisconnecting else { return false }
            return switch connection { case .disconnected, .failed: true; default: false }
        }
        public var canEditMessage: Bool {
            guard case .ready = connection else { return false }
            return projection?.status == .idle && !isSending && !isStopping
        }
        public var canSend: Bool { canEditMessage }
        public var canStop: Bool {
            guard case .ready = connection else { return false }
            return projection?.status == .running && !isSending && !isStopping
        }
        public var requiresDisconnectWarning: Bool {
            isSending || isStopping || (!canConnect && projection != nil && projection?.status != .idle)
        }
        public var statusText: String {
            if isDisconnecting { return "Disconnecting…" }
            switch connection {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting…"
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
    }

    public enum Action: Equatable, Sendable {
        case clearDraftConsumed
        case connectRequested(UUID = UUID(), takingControl: Bool)
        case sendRequested(UUID = UUID(), text: String)
        case stopRequested(UUID = UUID())
        case disconnectRequested(UUID = UUID())
        case connectionEndpointSelected(UUID, URL)
        case disconnectFinished(UUID)
        case connected(UUID, DemoSession)
        case connectionChanged(UUID, PiConnectionState)
        case projectionChanged(UUID, DemoSessionProjection)
        case failed(UUID, PiError)
        case sendFinished(UUID, submitted: String, error: PiError?)
        case stopFinished(UUID, error: PiError?)
    }

    public init() {}

    @MainActor public func reduce(_ state: inout State, _ action: Action) {
        switch action {
        case .clearDraftConsumed: state.clearDraftMatching = nil
        case .connectRequested(let token, let takingControl):
            guard takingControl, state.canConnect else { return }
            state.connectionEndpoint = nil
            state.generation = token; state.connection = .connecting
            state.projection = nil; state.actionError = nil; state.clearDraftMatching = nil
            state.isSending = false; state.isStopping = false
            state.sendRequest = nil; state.stopRequest = nil
        case .connectionEndpointSelected(let token, let endpoint):
            guard state.generation == token else { return }
            state.connectionEndpoint = endpoint
        case .connected(let token, let session):
            guard state.generation == token else { return }
            state.connection = .ready(session)
        case .connectionChanged(let token, let connection):
            guard state.generation == token else { return }
            state.connection = connection
        case .projectionChanged(let token, let projection):
            guard state.generation == token else { return }
            state.projection = projection
        case .failed(let token, let error):
            guard state.generation == token else { return }
            state.connection = .failed(error)
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
        case .disconnectRequested(let token):
            guard !state.isDisconnecting else { return }
            if state.isSending || state.isStopping {
                state.actionError = "Request outcome unknown after disconnect. Server work may continue; nothing will be resent automatically."
            } else if state.requiresDisconnectWarning {
                state.actionError = "Disconnected. Server work may continue; this did not stop or close the session."
            } else if state.connection == .connecting {
                state.actionError = "Disconnected during setup. A demo runtime may have been created on the server."
            }
            state.generation = token; state.connection = .disconnected; state.clearDraftMatching = nil
            state.isSending = false; state.isStopping = false; state.isDisconnecting = true
            state.sendRequest = nil; state.stopRequest = nil
        case .disconnectFinished(let token):
            guard state.generation == token else { return }
            state.isDisconnecting = false
        }
    }
}
