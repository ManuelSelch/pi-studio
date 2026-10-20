import FactoryKit
import Foundation
import PiSDK

/// One dependency scope per app lifetime (or preview/test). No global shared
/// container: registrations and cached controllers cannot leak between scopes.
@MainActor
public final class SessionDependencies: ManagedContainer {
    public nonisolated let manager = ContainerManager()

    public init() {}

    public var sessionConfiguration: Factory<SessionConfiguration> {
        self { SessionConfiguration.development }
    }

    public var makeConnection: Factory<@Sendable (URL) -> any PiDemoConnection> {
        self { { PiClient(endpoint: $0) } }
    }

    public var makeSessionConnection: Factory<@Sendable (URL) -> any PiSessionConnection> {
        self { { PiClient(endpoint: $0) } }
    }

    public var projectsController: Factory<ProjectsController> {
        self { @MainActor in
            ProjectsController(session: self.sessionController(), makeConnection: self.makeSessionConnection())
        }.cached
    }

    /// Resolve only on the main actor, after installing any overrides. Cache per
    /// container, not globally, so the shell and containers share one controller.
    public var sessionController: Factory<SessionController> {
        self { @MainActor in
            SessionController(configuration: self.sessionConfiguration(), makeConnection: self.makeConnection())
        }.cached
    }
}
