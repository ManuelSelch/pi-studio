import FactoryKit
import Foundation
import Flux
import PiSDK

/// One dependency scope per app lifetime (or preview/test). No global shared
/// container: registrations and cached stores cannot leak between scopes.
@MainActor
public final class SessionDependencies: ManagedContainer {
    public nonisolated let manager = ContainerManager()

    public init() {}

    public var endpointSettingsService: Factory<any EndpointSettingsService> {
        self { @MainActor in UserDefaultsEndpointSettingsService() }.cached
    }

    public var settingsController: Factory<SettingsController> {
        self { @MainActor in SettingsController(service: self.endpointSettingsService()) }.cached
    }

    public var sessionConfiguration: Factory<SessionConfiguration> {
        self { @MainActor in
            SessionConfiguration(endpoint: self.settingsController().endpoint,
                                 projectPath: SessionConfiguration.development.projectPath)
        }
    }

    public var makeConnection: Factory<@Sendable (URL) -> any PiDemoConnection> {
        self { { PiClient(endpoint: $0) } }
    }

    /// Each cached store owns a fresh middleware instance and its SDK lifetime.
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
}
