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
        store.dispatch(.draftChanged("Hello")) { $0.draft = "Hello" }
        #expect(store.state.canSend)
        store.dispatch(.sendStarted) { $0.isSending = true }
        #expect(!store.state.canSend)
        store.dispatch(.sendFinished(token, submitted: "Hello", error: nil)) { $0.isSending = false; $0.draft = "" }
        await store.finish()
    }

    @Test func attachingAnOpenedSessionResetsToReadyWithoutConnecting() async {
        var initial = SessionFeature.State()
        initial.connection = .failed(.disconnected)
        initial.actionError = "stale failure"
        initial.draft = "left in another session"
        let token = UUID()
        let opened = DemoSession(sessionId: "opened", projectPath: "/repo")
        let store = TestStore<SessionFeature>(state: initial)
        defer { store.tearDown() }
        store.dispatch(.attached(token, opened)) {
            $0 = SessionFeature.State(); $0.generation = token; $0.connection = .ready(opened)
        }
        #expect(store.state.errorMessage == nil)
        #expect(!store.state.canConnect)
        #expect(store.state.draft.isEmpty)
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
        store.dispatch(.failed(token, .disconnected)) { _ in }
        store.dispatch(.connected(token, .init(sessionId: "old", projectPath: "/tmp/old"))) { _ in }
        await store.finish()
    }

    @Test func changedDraftIsNotClearedByEarlierSend() async {
        let session = DemoSession(sessionId: "demo", projectPath: "/tmp/demo")
        var initial = SessionFeature.State()
        initial.connection = .ready(session); initial.projection = .init(session: session)
        initial.draft = "First"
        let store = TestStore<SessionFeature>(state: initial)
        defer { store.tearDown() }
        store.dispatch(.sendStarted) { $0.isSending = true }
        store.dispatch(.draftChanged("Next")) { $0.draft = "Next" }
        store.dispatch(.sendFinished(initial.generation, submitted: "First", error: nil)) { $0.isSending = false }
        await store.finish()
    }
}
