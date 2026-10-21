import Foundation
import Flux
import FactoryKit

@MainActor
public final class SettingsMiddleware: Middleware {
    public typealias F = SettingsFeature

    @Injected(\.endpointSettingsService) private var service
    private var store: StoreHandle<SettingsFeature>?
    private var handledRequest: UUID?

    public init() {}

    public func initialize(_ store: StoreHandle<SettingsFeature>) { self.store = store }

    public func handle(_ state: SettingsFeature.State, _ action: SettingsFeature.Action) async -> SettingsFeature.Action? {
        switch action {
        case .saveTapped(let request):
            // Flux passes the post-reducer snapshot: an accepted Save is already saving.
            guard state.isPresented, state.saveRequest == request,
                  store?.getState()?.saveRequest == request, handledRequest != request else { return nil }
            handledRequest = request
            guard let endpoint = ServerEndpoint.validated(state.draft) else {
                return .saveFailed(ServerEndpoint.validationMessage)
            }
            do {
                try service.save(endpoint)
                return .saved(endpoint)
            } catch {
                return .saveFailed(error.localizedDescription)
            }
        default:
            return nil
        }
    }
}
