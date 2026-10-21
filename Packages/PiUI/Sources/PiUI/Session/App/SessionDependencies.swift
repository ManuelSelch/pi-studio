import FactoryKit
import Foundation
import Flux
import PiSDK

/// One dependency scope per app lifetime (or preview/test). No global shared
/// container: registrations and cached stores cannot leak between scopes.
@MainActor
extension Container {
    public var endpointSettingsService: Factory<any EndpointSettingsService> {
        self { @MainActor in UserDefaultsEndpointSettingsService() }.cached
    }

    public var sessionConfiguration: Factory<SessionConfiguration> {
        self { @MainActor in
            SessionConfiguration.development
        }
    }

    public var makeConnection: Factory<@Sendable (URL) -> any PiDemoConnection> {
        self { { PiClient(endpoint: $0) } }
    }

    public var sessionStore: Factory<FluxStore<SessionFeature>> {
        self { @MainActor in
            let configuration = self.sessionConfiguration()
            let middleware = SessionMiddleware(
                configuration: configuration,
                endpointProvider: { [weak self] in self?.sessionConfiguration().endpoint ?? configuration.endpoint },
                makeConnection: self.makeConnection()
            )
            return FluxStore(state: .init(), middlewares: [middleware])
        }.cached
    }
    
    public var settingsStore: Factory<FluxStore<SettingsFeature>> {
        self { @MainActor in
            return FluxStore(state: .init(endpoint: ""), middlewares: [
                SettingsMiddleware()
            ])
        }.cached
    }
}
