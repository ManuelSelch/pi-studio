import Foundation
import Flux
import PiSDK

/// Owns the conversation's cancellable SDK work: the transcript subscription and send/stop.
///
/// The transport belongs to the workspace; this middleware only reads the connection it
/// publishes (`SessionTransport`). Requests reserve reducer state synchronously and results are
/// generation-checked, matching `SessionMiddleware`'s original contract.
@MainActor
public final class SessionMiddleware: Middleware {
    public typealias F = SessionFeature

    private let transport: SessionTransport
    private var store: StoreHandle<SessionFeature>?
    private var observation: Task<Void, Never>?
    private var sending: Task<Void, Never>?
    private var stopping: Task<Void, Never>?
    private var handledAttach: UUID?
    private var sendRequest: UUID?
    private var stopRequest: UUID?

    /// The transport is injected explicitly: the workspace owns it, and a property wrapper would
    /// resolve it outside the scope the store was created in.
    public init(transport: SessionTransport) { self.transport = transport }

    public func initialize(_ store: StoreHandle<SessionFeature>) { self.store = store }

    public func handle(_ state: SessionFeature.State, _ action: SessionFeature.Action) async -> SessionFeature.Action? {
        guard let store else { return nil }
        switch action {
        case .attachRequested(let request, let sessionId):
            guard state.attachRequest == request, store.getState()?.attachRequest == request,
                  handledAttach != request else { return nil }
            handledAttach = request
            observe(sessionId: sessionId, token: state.generation, store: store)
        case .detachRequested:
            observation?.cancel(); observation = nil
        case .sendRequested(let request, let submitted):
            guard state.sendRequest == request, store.getState()?.sendRequest == request,
                  sendRequest != request, let connection = transport.connection else { return nil }
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
                  stopRequest != request, let connection = transport.connection else { return nil }
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
        default:
            break
        }
        return nil
    }

    /// Subscribes to the transcript of exactly one runtime. Projections for any other runtime
    /// belong to a superseded switch and are dropped, so a late attach cannot be rendered.
    private func observe(sessionId: String, token: UUID, store: StoreHandle<SessionFeature>) {
        observation?.cancel()
        observation = nil
        guard let connection = transport.connection else { return }
        observation = Task {
            for await projection in await connection.projections() {
                guard !Task.isCancelled, store.getState()?.generation == token,
                      store.getState()?.observedSessionId == projection.session.sessionId else { continue }
                store.dispatch(.attached(token, projection.session))
                store.dispatch(.projectionChanged(token, projection))
            }
        }
    }

    private static func normalize(_ error: Error) -> PiError {
        (error as? PiError) ?? .transport(message: error.localizedDescription, outcomeUnknown: false)
    }

    deinit {
        observation?.cancel(); sending?.cancel(); stopping?.cancel()
    }
}
