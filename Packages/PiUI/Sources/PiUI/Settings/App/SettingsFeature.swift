import Flux
import Foundation

public struct SettingsFeature: Feature {
    public struct State: Equatable, Sendable {
        public internal(set) var savedEndpoint: String
        public internal(set) var draft: String
        public internal(set) var isPresented = false
        public internal(set) var saveRequest: UUID?
        public var isSaving: Bool { saveRequest != nil }
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
        
        case saveTapped(UUID = UUID())
        case saveFailed(String)
        case saved(String)
    }

    public init() {}

    @MainActor public func reduce(_ state: inout State, _ action: Action) {
        switch action {
        case .opened:
            guard !state.isSaving else { return }
            state.draft = state.savedEndpoint
            state.error = nil
            state.isPresented = true
        case .cancelled:
            guard !state.isSaving else { return }
            state.draft = state.savedEndpoint
            state.error = nil
            state.isPresented = false
        case .draftChanged(let value):
            guard !state.isSaving else { return }
            state.draft = value
            state.error = nil
        case .saveTapped(let request):
            guard state.isPresented, !state.isSaving else { return }
            state.saveRequest = request
            state.error = nil
        case .saveFailed(let message):
            state.saveRequest = nil
            state.error = message
        case .saved(let endpoint):
            state.savedEndpoint = endpoint
            state.draft = endpoint
            state.saveRequest = nil
            state.error = nil
            state.isPresented = false
        }
    }
}
