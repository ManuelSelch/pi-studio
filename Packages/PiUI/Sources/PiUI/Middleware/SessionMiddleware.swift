import Foundation
import Flux
import PiSDK

/// Owns cancellable SDK work and streams, never the concrete store.
/// Requests reserve reducer state synchronously; results are generation-checked.
@MainActor
public final class SessionMiddleware: Middleware {
    public typealias F = SessionFeature

    private let configuration: SessionConfiguration
    private let endpointProvider: @MainActor () -> URL
    private let makeConnection: @Sendable (URL) -> any PiDemoConnection
    private var store: StoreHandle<SessionFeature>?
    private var connection: (any PiDemoConnection)?
    private var connectionGeneration: UUID?
    private var disconnectRequest: UUID?
    private var connecting: Task<Void, Never>?
    private var sending: Task<Void, Never>?
    private var stopping: Task<Void, Never>?
    private var observation: Task<Void, Never>?
    private var sessionObservation: Task<Void, Never>?
    private var sendRequest: UUID?
    private var stopRequest: UUID?

    public init(configuration: SessionConfiguration = .development,
                endpointProvider: (@MainActor () -> URL)? = nil,
                makeConnection: @escaping @Sendable (URL) -> any PiDemoConnection = { PiClient(endpoint: $0) }) {
        self.configuration = configuration
        self.endpointProvider = endpointProvider ?? { configuration.endpoint }
        self.makeConnection = makeConnection
    }

    public func initialize(_ store: StoreHandle<SessionFeature>) { self.store = store }

    public func handle(_ state: SessionFeature.State, _ action: SessionFeature.Action) async -> SessionFeature.Action? {
        guard let store else { return nil }
        switch action {
        case .connectRequested(let token, let takingControl):
            guard takingControl, state.generation == token, state.connection == .connecting,
                  store.getState()?.generation == token, connectionGeneration != token else { return nil }
            beginConnect(token, store: store)
        case .sendRequested(let request, let submitted):
            guard state.sendRequest == request, store.getState()?.sendRequest == request,
                  store.getState()?.generation == state.generation, sendRequest != request,
                  connectionGeneration == state.generation, let connection else { return nil }
            sendRequest = request
            let token = state.generation
            sending = Task {
                guard !Task.isCancelled, store.getState()?.generation == token,
                      store.getState()?.sendRequest == request else { return }
                let error: PiError?
                do { try await connection.send(submitted); error = nil }
                catch let failure { error = Self.normalize(failure) }
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                store.dispatch(.sendFinished(token, submitted: submitted, error: error))
            }
        case .stopRequested(let request):
            guard state.stopRequest == request, store.getState()?.stopRequest == request,
                  store.getState()?.generation == state.generation, stopRequest != request,
                  connectionGeneration == state.generation, let connection else { return nil }
            stopRequest = request
            let token = state.generation
            stopping = Task {
                guard !Task.isCancelled, store.getState()?.generation == token,
                      store.getState()?.stopRequest == request else { return }
                let error: PiError?
                do { try await connection.stop(); error = nil }
                catch let failure { error = Self.normalize(failure) }
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                store.dispatch(.stopFinished(token, error: error))
            }
        case .disconnectRequested(let token):
            guard store.getState()?.generation == token, store.getState()?.isDisconnecting == true,
                  disconnectRequest != token else { return nil }
            disconnectRequest = token
            let pending = [connecting, sending, stopping, observation, sessionObservation]
            cancelWork()
            let previous = connection
            connection = nil; connectionGeneration = nil
            connecting = nil; sending = nil; stopping = nil
            await previous?.disconnect()
            for task in pending { await task?.value }
            disconnectRequest = nil
            return .disconnectFinished(token)
        default:
            break
        }
        return nil
    }

    private func beginConnect(_ token: UUID, store: StoreHandle<SessionFeature>) {
        let pending = [connecting, sending, stopping, observation, sessionObservation]
        cancelWork()
        let previous = connection
        let endpoint = endpointProvider()
        let client = makeConnection(endpoint)
        let projectPath = configuration.projectPath
        connection = client; connectionGeneration = token
        store.dispatch(.connectionEndpointSelected(token, endpoint))
        connecting = Task { [weak self] in
            await previous?.disconnect()
            for task in pending { await task?.value }
            guard !Task.isCancelled, store.getState()?.generation == token else {
                await client.disconnect()
                return
            }
            do {
                let session = try await client.connectDemo(projectPath: projectPath, takingControl: true)
                guard !Task.isCancelled, store.getState()?.generation == token else {
                    await client.disconnect()
                    return
                }
                self?.observe(client, token: token, store: store)
                store.dispatch(.connected(token, session))
            } catch {
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                self?.discardConnection(token: token)
                await client.disconnect()
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                store.dispatch(.failed(token, Self.normalize(error)))
            }
        }
    }

    private func observe(_ client: any PiDemoConnection, token: UUID, store: StoreHandle<SessionFeature>) {
        observation = Task {
            guard !Task.isCancelled, store.getState()?.generation == token else { return }
            for await state in await client.states() {
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                store.dispatch(.connectionChanged(token, state))
            }
        }
        sessionObservation = Task {
            guard !Task.isCancelled, store.getState()?.generation == token else { return }
            for await projection in await client.projections() {
                guard !Task.isCancelled, store.getState()?.generation == token else { return }
                store.dispatch(.projectionChanged(token, projection))
            }
        }
    }

    private func discardConnection(token: UUID) {
        guard connectionGeneration == token else { return }
        connection = nil; connectionGeneration = nil
    }

    private func cancelWork() {
        connecting?.cancel(); sending?.cancel(); stopping?.cancel()
        observation?.cancel(); observation = nil
        sessionObservation?.cancel(); sessionObservation = nil
        sendRequest = nil; stopRequest = nil
    }

    private static func normalize(_ error: Error) -> PiError {
        (error as? PiError) ?? .transport(message: error.localizedDescription, outcomeUnknown: false)
    }

    deinit {
        connecting?.cancel(); sending?.cancel(); stopping?.cancel()
        observation?.cancel(); sessionObservation?.cancel()
        let client = connection
        Task { await client?.disconnect() }
    }
}
