import Foundation

@MainActor
public final class UserDefaultsEndpointSettingsService: EndpointSettingsService {
    private let defaults: UserDefaults
    private let key = "pi.serverEndpoint"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> String? { defaults.string(forKey: key) }

    public func save(_ endpoint: String) throws {
        guard let value = ServerEndpoint.validated(endpoint) else {
            throw InvalidEndpoint()
        }
        defaults.set(value, forKey: key)
    }

    private struct InvalidEndpoint: LocalizedError {
        var errorDescription: String? { ServerEndpoint.validationMessage }
    }
}
