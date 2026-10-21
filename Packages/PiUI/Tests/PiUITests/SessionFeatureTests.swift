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

    @Test func connectionAndSnapshotAdmissionAreReducedByFlux() async {
        let token = UUID()
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        let store = TestStore<SessionFeature>(state: .init())
        defer { store.tearDown() }
        store.dispatch(.connectRequested(token, takingControl: true)) { $0.generation = token; $0.connection = .connecting }
        store.dispatch(.connected(token, session)) { $0.connection = .ready(session) }
        store.dispatch(.projectionChanged(token, .init(session: session))) { $0.projection = .init(session: session) }
        #expect(store.state.canSend)
        let request = UUID()
        store.dispatch(.sendRequested(request, text: "Hello")) { $0.isSending = true; $0.sendRequest = request }
        #expect(!store.state.canSend)
        store.dispatch(.sendFinished(token, submitted: "Hello", error: nil)) {
            $0.isSending = false; $0.sendRequest = nil; $0.clearDraftMatching = "Hello"
        }
        await store.finish()
    }

    @Test func staleCallbacksCannotOverwriteDisconnectedState() async {
        let token = UUID()
        let store = TestStore<SessionFeature>(state: .init())
        defer { store.tearDown() }
        store.dispatch(.connectRequested(token, takingControl: true)) { $0.generation = token; $0.connection = .connecting }
        let next = UUID()
        store.dispatch(.disconnectRequested(next)) {
            $0.generation = next; $0.connection = .disconnected; $0.isDisconnecting = true
            $0.actionError = "Disconnected during setup. A demo runtime may have been created on the server."
        }
        store.dispatch(.sendFinished(token, submitted: "Old", error: nil)) { _ in }
        store.dispatch(.failed(token, .disconnected)) { _ in }
        let old = DemoSession(sessionId: "old", projectPath: "/tmp/old")
        store.dispatch(.connected(token, old)) { _ in }
        store.dispatch(.projectionChanged(token, .init(session: old))) { _ in }
        store.dispatch(.connectionChanged(token, .ready(old))) { _ in }
        store.dispatch(.stopFinished(token, error: nil)) { _ in }
        await store.finish()
    }

    @Test func consecutiveIdenticalSubmissionsIssueConsumableClearInstructions() async {
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        var initial = SessionFeature.State()
        initial.connection = .ready(session); initial.projection = .init(session: session)
        let store = TestStore<SessionFeature>(state: initial)
        defer { store.tearDown() }
        for _ in 0..<2 {
            let request = UUID()
            store.dispatch(.sendRequested(request, text: "First")) { $0.isSending = true; $0.sendRequest = request }
            store.dispatch(.sendFinished(initial.generation, submitted: "First", error: nil)) {
                $0.isSending = false; $0.sendRequest = nil; $0.clearDraftMatching = "First"
            }
            store.dispatch(.clearDraftConsumed) { $0.clearDraftMatching = nil }
        }
        let request = UUID()
        store.dispatch(.sendRequested(request, text: "First")) { $0.isSending = true; $0.sendRequest = request }
        store.dispatch(.sendFinished(initial.generation, submitted: "First", error: nil)) {
            $0.isSending = false; $0.sendRequest = nil; $0.clearDraftMatching = "First"
        }
        let retry = UUID()
        store.dispatch(.sendRequested(retry, text: "First")) {
            $0.isSending = true; $0.sendRequest = retry; $0.clearDraftMatching = nil
        }
        store.dispatch(.sendFinished(initial.generation, submitted: "First", error: .disconnected)) {
            $0.isSending = false; $0.sendRequest = nil; $0.actionError = PiError.disconnected.localizedDescription
        }
        await store.finish()
    }

    @Test func reducerRejectsWhitespaceAndUnavailableSnapshots() async {
        var state = SessionFeature.State()
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        let feature = SessionFeature()
        let disconnected = state
        feature.reduce(&state, .sendRequested(text: "Not connected"))
        #expect(state == disconnected)
        state.connection = .ready(session); state.projection = .init(session: session)
        let ready = state
        for text in ["", " ", "\n\t\n"] {
            feature.reduce(&state, .sendRequested(text: text))
            #expect(state == ready)
        }
        state.projection = .init(session: session, status: .running)
        let running = state
        feature.reduce(&state, .sendRequested(text: "Busy"))
        #expect(state == running)
    }
}
