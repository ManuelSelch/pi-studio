import Flux
import Foundation
import PiSDK
import Testing
@testable import PiUI

/// The conversation reducer: it knows only the runtime the workspace attached.
@MainActor
struct SessionFeatureTests {
    private struct Fixture {
        let store: FluxStore<SessionFeature>
        let token: UUID
        let session: DemoSession
    }

    private func fixture(_ sessionId: String = "demo") -> Fixture {
        let token = UUID()
        let session = DemoSession(sessionId: sessionId, projectPath: "/tmp/demo")
        var state = SessionFeature.State()
        state.generation = token
        state.observedSessionId = sessionId
        state.connection = .ready(session)
        state.projection = .init(session: session)
        return Fixture(store: FluxStore(state: state), token: token, session: session)
    }

    @Test func attachingARuntimeIsNotReadyUntilItsProjectionArrives() {
        let store = FluxStore<SessionFeature>(state: .init())
        #expect(!store.state.canEditMessage)
        store.dispatch(.attachRequested(sessionId: "opened"))
        #expect(store.state.statusText == "Attaching…")
        #expect(store.state.observedSessionId == "opened")
        #expect(!store.state.canEditMessage)
        let session = DemoSession(sessionId: "opened", projectPath: "/repo")
        store.dispatch(.attached(store.state.generation, session))
        // Ready means the runtime is known; the transcript still has to arrive.
        #expect(store.state.connection == .ready(session))
        #expect(!store.state.canSend)
        store.dispatch(.projectionChanged(store.state.generation, .init(session: session)))
        #expect(store.state.canEditMessage)
        #expect(store.state.canSend)
        #expect(store.state.statusText == "Ready")
    }

    @Test func attachingAnotherRuntimeDiscardsTheSupersededTranscriptAndWork() {
        let fixture = fixture("first")
        let store = fixture.store
        store.dispatch(.sendRequested(text: "Keep going"))
        #expect(store.state.isSending)
        // Switching tabs attaches another runtime: the old transcript and work are dropped.
        store.dispatch(.attachRequested(sessionId: "second"))
        #expect(store.state.projection == nil)
        #expect(!store.state.isSending)
        #expect(store.state.observedSessionId == "second")
        #expect(!store.state.canEditMessage)
        // Late results for the previous runtime cannot settle anywhere.
        let current = store.state
        store.dispatch(.sendFinished(fixture.token, submitted: "Keep going", error: nil))
        store.dispatch(.projectionChanged(fixture.token, .init(session: fixture.session)))
        store.dispatch(.stopFinished(fixture.token, error: nil))
        store.dispatch(.attached(fixture.token, fixture.session))
        #expect(store.state == current)
    }

    @Test func detachingResetsTheConversationWithoutTouchingTheTransport() {
        let store = fixture("first").store
        store.dispatch(.detachRequested())
        #expect(store.state.observedSessionId == nil)
        #expect(store.state.projection == nil)
        #expect(store.state.connection == .disconnected)
        let detached = store.state
        store.dispatch(.sendFinished(UUID(), submitted: "Old", error: nil))
        store.dispatch(.projectionChanged(UUID(), .init(session: DemoSession(sessionId: "first", projectPath: "/tmp/demo"))))
        #expect(store.state == detached)
    }

    @Test func reducerRejectsWhitespaceAndUnavailableSnapshots() {
        let feature = SessionFeature()
        var state = SessionFeature.State()
        let detached = state
        feature.reduce(&state, .sendRequested(text: "Not attached"))
        #expect(state == detached)
        state = fixture().store.state
        let available = state
        for text in ["", " ", "\n\t\n"] {
            feature.reduce(&state, .sendRequested(text: text))
            #expect(state == available)
        }
        state.projection = .init(session: .init(sessionId: "demo", projectPath: "/tmp/demo"), status: .running)
        let running = state
        feature.reduce(&state, .sendRequested(text: "Busy"))
        #expect(state == running)
    }

    @Test func consecutiveIdenticalSubmissionsIssueConsumableClearInstructions() {
        let fixture = fixture()
        let store = fixture.store
        for _ in 0..<2 {
            store.dispatch(.sendRequested(text: "First"))
            #expect(store.state.isSending)
            store.dispatch(.sendFinished(fixture.token, submitted: "First", error: nil))
            #expect(store.state.clearDraftMatching == "First")
            store.dispatch(.clearDraftConsumed)
            #expect(store.state.clearDraftMatching == nil)
        }
        store.dispatch(.sendRequested(text: "First"))
        store.dispatch(.sendFinished(fixture.token, submitted: "First", error: .disconnected))
        #expect(store.state.clearDraftMatching == nil)
        #expect(store.state.actionError == PiError.disconnected.localizedDescription)
    }
}
