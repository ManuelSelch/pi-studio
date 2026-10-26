import Foundation

public struct SessionConfiguration: Sendable {
    public let endpoint: URL
    public let projectPath: String

    public init(endpoint: URL, projectPath: String) {
        self.endpoint = endpoint; self.projectPath = projectPath
    }

    /// Simulator/Mac development only. The directory is on the server.
    public static let development = SessionConfiguration(
        endpoint: URL(string: "ws://127.0.0.1:8787/ws")!,
        projectPath: "/tmp/pi-studio-demo"
    )
}
