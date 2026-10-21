import Foundation
import Flux
import FactoryKit

public class SettingsMiddleware: Middleware {
    public typealias F = SettingsFeature
    
    @Injected(\.endpointSettingsService) var service
    
    public func handle(_ state: SettingsFeature.State, _ action: SettingsFeature.Action) async -> SettingsFeature.Action? {
        switch action {
        case .saveTapped:
            guard state.isPresented, !state.isSaving else { break }
            guard let endpoint = ServerEndpoint.validated(state.draft) else {
                return .saveFailed(ServerEndpoint.validationMessage)
            }
            
            do {
                try service.save(endpoint)
                return .saved(endpoint)
            } catch {
                return .saveFailed(error.localizedDescription)
            }
            break
        default:
            break
        }
        
        return .none
    }
}
