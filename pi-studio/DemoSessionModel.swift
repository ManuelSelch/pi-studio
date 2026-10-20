import Foundation
import Observation
import PiSDK

nonisolated struct DemoConfiguration: Sendable {
    let endpoint: URL
    let projectPath: String

    // Simulator-only development defaults. The directory is on the server.
    static let development = DemoConfiguration(
        endpoint: URL(string: "ws://localhost:8787/ws")!,
        projectPath: "/tmp/pi-studio-demo"
    )
}

/// App-owned presentation only. Protocol/session ownership stays in PiSDK.
/// No connection is opened on launch; a future screen must explicitly confirm
/// that Connect takes controller access away from any existing client.
@MainActor @Observable
final class DemoSessionModel {
    private(set) var state: PiConnectionState = .disconnected
    let configuration: DemoConfiguration
    @ObservationIgnored private let makeConnection: @Sendable (URL) -> any PiDemoConnection
    @ObservationIgnored private var connection: (any PiDemoConnection)?
    @ObservationIgnored private var observation: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()

    init(configuration: DemoConfiguration = .development,
         makeConnection: @escaping @Sendable (URL) -> any PiDemoConnection = { PiClient(endpoint: $0) }) {
        self.configuration = configuration
        self.makeConnection = makeConnection
    }

    func connect(takingControl: Bool) async {
        guard takingControl else { return }
        switch state {
        case .connecting, .ready: return
        case .disconnected, .failed: break
        }
        let token = UUID()
        generation = token
        state = .connecting
        let client = makeConnection(configuration.endpoint)
        connection = client
        do {
            let session = try await client.connectDemo(projectPath: configuration.projectPath, takingControl: true)
            guard generation == token else { return }
            state = .ready(session)
            observation?.cancel()
            observation = Task { [weak self] in
                for await state in await client.states() {
                    guard !Task.isCancelled, let self, self.generation == token else { return }
                    self.state = state
                }
            }
        } catch {
            guard generation == token else { return }
            state = .failed((error as? PiError) ?? .transport(message: error.localizedDescription, outcomeUnknown: false))
            connection = nil
            await client.disconnect()
        }
    }

    func disconnect() async {
        generation = UUID()
        observation?.cancel(); observation = nil
        let previous = connection
        connection = nil
        state = .disconnected
        await previous?.disconnect()
    }

    deinit {
        observation?.cancel()
        let client = connection
        Task { await client?.disconnect() }
    }
}
