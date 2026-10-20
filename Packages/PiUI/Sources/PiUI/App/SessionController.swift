import Foundation
import Flux
import PiSDK

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

/// SDK effect/lifecycle owner, not a second observable model. Every UI-state
/// mutation is a Flux action. Async operations remain explicitly awaitable so
/// platform teardown and tests can await disposal, including during setup.
@MainActor public final class SessionController {
    public let store: FluxStore<SessionFeature>
    public let configuration: SessionConfiguration
    public var state: SessionFeature.State { store.state }
    private let makeConnection: @Sendable (URL) -> any PiDemoConnection
    private var connection: (any PiDemoConnection)?
    private var observation: Task<Void, Never>?
    private var sessionObservation: Task<Void, Never>?

    public init(configuration: SessionConfiguration = .development,
                makeConnection: @escaping @Sendable (URL) -> any PiDemoConnection = { PiClient(endpoint: $0) }) {
        self.configuration = configuration
        self.makeConnection = makeConnection
        store = FluxStore(state: .init())
    }

    public func setDraft(_ value: String) { store.dispatch(.draftChanged(value)) }

    public func connect(takingControl: Bool) async {
        guard takingControl, state.canConnect else { return }
        let token = UUID()
        observation?.cancel(); sessionObservation?.cancel()
        store.dispatch(.connectStarted(token))
        let previous = connection; connection = nil
        await previous?.disconnect()
        guard state.generation == token else { return }
        let client = makeConnection(configuration.endpoint)
        connection = client
        do {
            let session = try await client.connectDemo(projectPath: configuration.projectPath, takingControl: true)
            guard state.generation == token else { return }
            store.dispatch(.connected(token, session))
            observation = Task { [weak self] in
                for await state in await client.states() {
                    guard !Task.isCancelled, let self, self.state.generation == token else { return }
                    self.store.dispatch(.connectionChanged(token, state))
                }
            }
            sessionObservation = Task { [weak self] in
                for await projection in await client.projections() {
                    guard !Task.isCancelled, let self, self.state.generation == token else { return }
                    self.store.dispatch(.projectionChanged(token, projection))
                }
            }
        } catch {
            guard state.generation == token else { return }
            store.dispatch(.failed(token, normalize(error)))
            connection = nil
            await client.disconnect()
        }
    }

    public func send() async {
        guard state.canSend, let connection else { return }
        let token = state.generation
        let submitted = state.draft
        store.dispatch(.sendStarted)
        do {
            try await connection.send(submitted)
            store.dispatch(.sendFinished(token, submitted: submitted, error: nil))
        } catch {
            store.dispatch(.sendFinished(token, submitted: submitted, error: normalize(error)))
        }
    }

    public func stop() async {
        guard state.canStop, let connection else { return }
        let token = state.generation
        store.dispatch(.stopStarted)
        do {
            try await connection.stop()
            store.dispatch(.stopFinished(token, error: nil))
        } catch {
            store.dispatch(.stopFinished(token, error: normalize(error)))
        }
    }

    public func disconnect() async {
        observation?.cancel(); observation = nil
        sessionObservation?.cancel(); sessionObservation = nil
        let previous = connection; connection = nil
        store.dispatch(.disconnected(UUID()))
        await previous?.disconnect()
    }

    private func normalize(_ error: Error) -> PiError {
        (error as? PiError) ?? .transport(message: error.localizedDescription, outcomeUnknown: false)
    }

    deinit {
        observation?.cancel(); sessionObservation?.cancel()
        let client = connection
        Task { await client?.disconnect() }
    }
}
