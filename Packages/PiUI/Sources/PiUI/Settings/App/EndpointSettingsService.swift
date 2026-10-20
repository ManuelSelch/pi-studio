/// Small synchronous boundary: saving a preference does not start networking.
/// Only the production adapter knows about UserDefaults.
@MainActor
public protocol EndpointSettingsService: AnyObject {
    func load() -> String?
    func save(_ endpoint: String) throws
}
