import Flux

public struct SettingsFeature: Feature {
    public struct State: Equatable, Sendable {
        public internal(set) var savedEndpoint: String
        public internal(set) var draft: String
        public internal(set) var isPresented = false
        public internal(set) var isSaving = false
        public internal(set) var error: String?

        public init(endpoint: String) {
            savedEndpoint = endpoint
            draft = endpoint
        }
    }

    public enum Action: Equatable, Sendable {
        case opened
        case cancelled
        case draftChanged(String)
        case saveStarted
        case saveFailed(String)
        case saved(String)
    }

    public init() {}

    @MainActor public func reduce(_ state: inout State, _ action: Action) {
        switch action {
        case .opened:
            state.draft = state.savedEndpoint
            state.error = nil
            state.isPresented = true
        case .cancelled:
            state.draft = state.savedEndpoint
            state.error = nil
            state.isPresented = false
        case .draftChanged(let value):
            guard !state.isSaving else { return }
            state.draft = value
            state.error = nil
        case .saveStarted:
            state.isSaving = true
            state.error = nil
        case .saveFailed(let message):
            state.isSaving = false
            state.error = message
        case .saved(let endpoint):
            state.savedEndpoint = endpoint
            state.draft = endpoint
            state.isSaving = false
            state.error = nil
            state.isPresented = false
        }
    }
}
