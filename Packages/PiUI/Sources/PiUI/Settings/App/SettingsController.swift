import Foundation
import Flux

@MainActor
public final class SettingsController {
    public let store: FluxStore<SettingsFeature>
    private let service: any EndpointSettingsService
    public var endpoint: URL { URL(string: store.state.savedEndpoint)! }

    public init(service: any EndpointSettingsService) {
        self.service = service
        let endpoint = service.load().flatMap(ServerEndpoint.validated) ?? ServerEndpoint.defaultValue
        store = FluxStore(state: .init(endpoint: endpoint))
    }

    public func open() { store.dispatch(.opened) }
    public func cancel() { store.dispatch(.cancelled) }
    public func setDraft(_ value: String) { store.dispatch(.draftChanged(value)) }

    public func save() {
        guard store.state.isPresented, !store.state.isSaving else { return }
        guard let endpoint = ServerEndpoint.validated(store.state.draft) else {
            store.dispatch(.saveFailed(ServerEndpoint.validationMessage))
            return
        }
        store.dispatch(.saveStarted)
        do {
            try service.save(endpoint)
            store.dispatch(.saved(endpoint))
        } catch {
            store.dispatch(.saveFailed(error.localizedDescription))
        }
    }
}
