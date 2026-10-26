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

    /// The workspace browses and opens sessions, so it needs the cataloguing connection.
    public var makeSessionConnection: Factory<@Sendable (URL) -> any PiSessionConnection> {
        self { { PiClient(endpoint: $0) } }
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

    /// The single seam between the workspace, which owns the connection, and the conversation.
    public var sessionTransport: Factory<SessionTransport> {
        self { @MainActor in SessionTransport() }.cached
    }

    /// The conversation of the session the workspace has attached.
    public var sessionStore: Factory<FluxStore<SessionFeature>> {
        self { @MainActor in
            FluxStore(state: .init(), middlewares: [SessionMiddleware(transport: self.sessionTransport())])
        }.cached
    }

    /// Navigation and transport: projects, open sessions, selection and the connection.
    public var workspaceStore: Factory<FluxStore<WorkspaceFeature>> {
        self { @MainActor in
            let middleware = WorkspaceMiddleware(
                transport: self.sessionTransport(),
                sessionStore: self.sessionStore(),
                endpointProvider: { [weak self] in
                    let saved = self?.settingsStore().state.savedEndpoint ?? ServerEndpoint.defaultValue
                    return URL(string: saved) ?? URL(string: ServerEndpoint.defaultValue)!
                },
                makeConnection: self.makeSessionConnection()
            )
            return FluxStore(state: .init(), middlewares: [middleware])
        }.cached
    }
}
