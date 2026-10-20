import Foundation
import Flux
import PiSDK

/// App-owned interaction state only. PiSDK remains authoritative for sessions.
public struct SessionFeature: Feature {
    public struct State: Equatable, Sendable {
        public internal(set) var connection: PiConnectionState = .disconnected
        public internal(set) var connectionEndpoint: URL?
        public internal(set) var projection: DemoSessionProjection?
        public internal(set) var draft = ""
        public internal(set) var isSending = false
        public internal(set) var isStopping = false
        public internal(set) var actionError: String?
        internal var generation = UUID()

        public init() {}

        public var canConnect: Bool {
            switch connection { case .disconnected, .failed: true; default: false }
        }
        public var canEditMessage: Bool {
            guard case .ready = connection else { return false }
            return projection?.status == .idle && !isSending && !isStopping
        }
        public var canSend: Bool { canEditMessage && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        public var canStop: Bool {
            guard case .ready = connection else { return false }
            return projection?.status == .running && !isSending && !isStopping
        }
        public var requiresDisconnectWarning: Bool {
            isSending || isStopping || (!canConnect && projection != nil && projection?.status != .idle)
        }
        public var statusText: String {
            switch connection {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting…"
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
        public var hint: String {
            if case .connecting = connection { return "Initializing and creating the demo…" }
            if requiresDisconnectWarning { return "Partial text stays visible." }
            return canConnect ? "Connect to start a fresh demo." : "One message at a time."
        }
    }

    public enum Action: Equatable, Sendable {
        case draftChanged(String)
        case connectStarted(UUID, endpoint: URL? = nil)
        case connected(UUID, DemoSession)
        case connectionChanged(UUID, PiConnectionState)
        case projectionChanged(UUID, DemoSessionProjection)
        case failed(UUID, PiError)
        case sendStarted
        case sendFinished(UUID, submitted: String, error: PiError?)
        case stopStarted
        case stopFinished(UUID, error: PiError?)
        case disconnected(UUID)
    }

    public init() {}

    @MainActor public func reduce(_ state: inout State, _ action: Action) {
        switch action {
        case .draftChanged(let draft): state.draft = draft
        case .connectStarted(let token, let endpoint):
            guard state.canConnect else { return }
            state.connectionEndpoint = endpoint
            state.generation = token; state.connection = .connecting
            state.projection = nil; state.actionError = nil
            state.isSending = false; state.isStopping = false
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
        case .sendStarted:
            guard state.canSend else { return }
            state.isSending = true; state.actionError = nil
        case .sendFinished(let token, let submitted, let error):
            guard state.generation == token else { return }
            if let error {
                state.actionError = error.localizedDescription
                if error.isOutcomeUnknown { state.connection = .failed(error) }
            } else if state.draft == submitted { state.draft = "" }
            state.isSending = false
        case .stopStarted:
            guard state.canStop else { return }
            state.isStopping = true; state.actionError = nil
        case .stopFinished(let token, let error):
            guard state.generation == token else { return }
            if let error {
                state.actionError = error.localizedDescription
                if error.isOutcomeUnknown { state.connection = .failed(error) }
            }
            state.isStopping = false
        case .disconnected(let token):
            if state.isSending || state.isStopping {
                state.actionError = "Request outcome unknown after disconnect. Server work may continue; nothing will be resent automatically."
            } else if state.requiresDisconnectWarning {
                state.actionError = "Disconnected. Server work may continue; this did not stop or close the session."
            } else if state.connection == .connecting {
                state.actionError = "Disconnected during setup. A demo runtime may have been created on the server."
            }
            state.generation = token; state.connection = .disconnected
            state.isSending = false; state.isStopping = false
        }
    }
}
