import Foundation
import Flux
import PiSDK

public struct ProjectsFeature: Feature {
    public struct State: Equatable, Sendable {
        public internal(set) var connection: PiConnectionState = .disconnected
        public internal(set) var catalogue = PiCatalogue()
        public internal(set) var selected: DemoSession?
        public internal(set) var title = ""
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
        public var status: String {
            switch connection {
            case .disconnected: "Disconnected"
            case .connecting: "Connecting…"
            case .failed(let error): error.isOutcomeUnknown ? "Outcome unknown" : "Connection failed"
            case .connected, .ready: isOpening ? "Opening…" : "Connected"
            }
        }
    }
    public enum Action: Equatable, Sendable {
        case connecting(UUID)
        case connectionChanged(UUID, PiConnectionState)
        case catalogueChanged(UUID, PiCatalogue)
        case opening
        case opened(UUID, DemoSession, String)
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
            if case .ready(let session) = value, state.selected != nil, !state.isOpening { state.selected = session }
            if case .failed(let error) = value { state.error = error.localizedDescription; state.isOpening = false }
            if value == .connected, state.selected != nil { state.selected = nil }
        case .catalogueChanged(let token, let catalogue):
            guard token == state.generation else { return }
            state.catalogue = catalogue
        case .opening:
            guard state.canOpen else { return }
            state.isOpening = true; state.error = nil
        case .opened(let token, let session, let title):
            guard token == state.generation else { return }
            state.selected = session; state.title = title; state.isOpening = false
        case .failed(let token, let error):
            guard token == state.generation else { return }
            state.error = error.localizedDescription; state.isOpening = false
            if error.isOutcomeUnknown { state.unknownOutcome = true }
        case .back:
            guard !state.isOpening else { return }
            state.selected = nil; state.error = nil
        case .disconnected(let token):
            state.generation = token; state.connection = .disconnected; state.isOpening = false
        }
    }
}
