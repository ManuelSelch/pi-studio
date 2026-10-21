import FactoryKit
import Foundation
import Flux
import PiSDK

/// The app uses Container.shared; tests/previews can own independent containers.
/// Registrations and cached stores remain local to their container.
@MainActor
extension Container {
    public var endpointSettingsService: Factory<any EndpointSettingsService> {
        self { @MainActor in UserDefaultsEndpointSettingsService() }.cached
    }

    public var sessionConfiguration: Factory<SessionConfiguration> {
        self { @MainActor in
            SessionConfiguration(endpoint: URL(string: self.settingsStore().state.savedEndpoint)!,
                                 projectPath: SessionConfiguration.development.projectPath)
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
            let service = self.endpointSettingsService()
            let endpoint = service.load().flatMap(ServerEndpoint.validated) ?? ServerEndpoint.defaultValue
            // @Injected resolves at construction; use this factory's container,
            // including when tests resolve from an independent scope.
            let middleware = Container.$shared.withValue(self) { SettingsMiddleware() }
            return FluxStore(state: .init(endpoint: endpoint), middlewares: [middleware])
        }.cached
    }
}
