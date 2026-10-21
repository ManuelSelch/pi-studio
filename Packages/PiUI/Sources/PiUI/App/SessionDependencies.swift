import FactoryKit
import Foundation
import PiSDK

/// One dependency scope per app lifetime (or preview/test). No global shared
/// container: registrations and cached controllers cannot leak between scopes.
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

    public var makeSessionConnection: Factory<@Sendable (URL) -> any PiSessionConnection> {
        self { { PiClient(endpoint: $0) } }
    }

    /// One workspace coordinator owns browsing, the shared connection and session
    /// selection. Conversations adopt that connection instead of opening their own.
    public var workspaceController: Factory<WorkspaceController> {
        self { @MainActor in
            WorkspaceController(session: self.sessionController(), makeConnection: self.makeSessionConnection())
        }.cached
    }

    /// Resolve only on the main actor, after installing any overrides. Cache per
    /// container, not globally, so the shell and containers share one controller.
    public var sessionController: Factory<SessionController> {
        self { @MainActor in
            let configuration = self.sessionConfiguration()
            return SessionController(
                configuration: configuration,
                endpointProvider: { [weak self] in self?.sessionConfiguration().endpoint ?? configuration.endpoint },
                makeConnection: self.makeConnection()
            )
        }.cached
    }
}
