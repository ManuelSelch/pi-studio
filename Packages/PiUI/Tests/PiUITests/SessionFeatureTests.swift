import Foundation
import FluxTestStore
import PiSDK
import Testing
@testable import PiUI

@MainActor
struct SessionFeatureTests {
    @Test func connectedWithoutSessionIsNotReadyForMessaging() async {
        let initial = SessionFeature.State()
        let store = TestStore<SessionFeature>(state: initial)
        defer { store.tearDown() }
        store.dispatch(.connectionChanged(initial.generation, .connected)) { $0.connection = .connected }
        #expect(store.state.statusText == "Connected")
        #expect(!store.state.canConnect)
        #expect(!store.state.canEditMessage)
        #expect(!store.state.canSend)
        #expect(!store.state.canStop)
        await store.finish()
    }

    @Test func connectionAndDraftAdmissionAreReducedByFlux() async {
        let initial = SessionFeature.State()
        let token = UUID()
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        let store = TestStore<SessionFeature>(state: initial)
        defer { store.tearDown() }
        store.dispatch(.connectStarted(token)) { $0.generation = token; $0.connection = .connecting }
        store.dispatch(.connected(token, session)) { $0.connection = .ready(session) }
        store.dispatch(.projectionChanged(token, .init(session: session))) { $0.projection = .init(session: session) }
        #expect(store.state.canSend)
        store.dispatch(.sendStarted) { $0.isSending = true }
        #expect(!store.state.canSend)
        store.dispatch(.sendFinished(token, submitted: "Hello", error: nil)) { $0.isSending = false; $0.clearDraftMatching = "Hello" }
        await store.finish()
    }

    @Test func staleCallbacksCannotOverwriteDisconnectedState() async {
        let token = UUID()
        let store = TestStore<SessionFeature>(state: .init())
        defer { store.tearDown() }
        store.dispatch(.connectStarted(token)) { $0.generation = token; $0.connection = .connecting }
        let next = UUID()
        store.dispatch(.disconnected(next)) {
            $0.generation = next; $0.connection = .disconnected
            $0.actionError = "Disconnected during setup. A demo runtime may have been created on the server."
        }
        store.dispatch(.sendFinished(token, submitted: "Old", error: nil)) { _ in }
        store.dispatch(.failed(token, .disconnected)) { _ in }
        store.dispatch(.connected(token, .init(sessionId: "old", projectPath: "/tmp/old"))) { _ in }
        await store.finish()
    }

    @Test func consecutiveIdenticalSubmissionsIssueConsumableClearInstructions() async {
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        var initial = SessionFeature.State()
        initial.connection = .ready(session); initial.projection = .init(session: session)
        let store = TestStore<SessionFeature>(state: initial)
        defer { store.tearDown() }
        store.dispatch(.sendStarted) { $0.isSending = true }
        store.dispatch(.sendFinished(initial.generation, submitted: "First", error: nil)) {
            $0.isSending = false; $0.clearDraftMatching = "First"
        }
        store.dispatch(.clearDraftConsumed) { $0.clearDraftMatching = nil }
        store.dispatch(.sendStarted) { $0.isSending = true }
        store.dispatch(.sendFinished(initial.generation, submitted: "First", error: nil)) {
            $0.isSending = false; $0.clearDraftMatching = "First"
        }
        store.dispatch(.sendStarted) { $0.isSending = true; $0.clearDraftMatching = nil }
        store.dispatch(.sendFinished(initial.generation, submitted: "First", error: .disconnected)) {
            $0.isSending = false; $0.actionError = PiError.disconnected.localizedDescription
        }
        await store.finish()
    }
}
