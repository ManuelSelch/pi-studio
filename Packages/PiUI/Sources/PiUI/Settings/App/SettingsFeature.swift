import Flux
import Foundation

public struct SettingsFeature: Feature {
    public struct State: Equatable, Sendable {
        public internal(set) var savedEndpoint: String
        public internal(set) var draft: String
        public internal(set) var isSaving = false
        public internal(set) var error: String?

        public init(endpoint: String) {
            savedEndpoint = endpoint
            draft = endpoint
        }
    }

    public enum Action: Equatable, Sendable {
        /// A request to open settings. The middleware presents through the router; a duplicate
        /// request preserves the active flow, draft and error.
        case opened
        /// A new flow was actually admitted by the middleware; only then are draft and error reset.
        case flowStarted

        case cancelTapped
        case draftChanged(String)

        case saveTapped
        /// The middleware refused a save because no flow was presented; nothing was persisted.
        case saveAbandoned
        case saveFailed(String)
        case saved(String)
    }

    public init() {}

    @MainActor public func reduce(_ state: inout State, _ action: Action) {
        switch action {
        case .flowStarted:
            state.draft = state.savedEndpoint
            state.error = nil
        case .draftChanged(let value):
            guard !state.isSaving else { return }
            state.draft = value
            state.error = nil
        case .saveTapped:
            guard !state.isSaving else { return }
            state.isSaving = true
            state.error = nil
        case .saveAbandoned:
            state.isSaving = false
        case .saveFailed(let message):
            state.isSaving = false
            state.error = message
        case .saved(let endpoint):
            state.savedEndpoint = endpoint
            state.draft = endpoint
            state.isSaving = false
            state.error = nil
        default:
            break
        }
    }
}
