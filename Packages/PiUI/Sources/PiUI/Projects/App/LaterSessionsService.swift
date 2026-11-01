import Foundation

@MainActor public protocol LaterSessionsService {
    func load(endpoint: URL) -> Set<String>
    func save(_ paths: Set<String>, endpoint: URL)
}

@MainActor public final class UserDefaultsLaterSessionsService: LaterSessionsService {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load(endpoint: URL) -> Set<String> {
        Set(defaults.stringArray(forKey: key(endpoint)) ?? [])
    }

    public func save(_ paths: Set<String>, endpoint: URL) {
        defaults.set(paths.sorted(), forKey: key(endpoint))
    }

    private func key(_ endpoint: URL) -> String {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return "pi.laterSessions.\(endpoint.absoluteString)"
        }
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        if (components.scheme == "ws" && components.port == 80)
            || (components.scheme == "wss" && components.port == 443) { components.port = nil }
        return "pi.laterSessions.\(components.string ?? endpoint.absoluteString)"
    }
}
