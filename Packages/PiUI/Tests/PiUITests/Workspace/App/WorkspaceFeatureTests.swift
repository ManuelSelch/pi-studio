import Flux
import Foundation
import PiSDK
import Testing
@testable import PiUI

/// Open-session ordering, selection and per-session local state are reduced by Flux
/// alone: no SDK, no connection and no async work is involved.
@MainActor
struct WorkspaceFeatureTests {
    private let scope = "ws://test:8787/ws"

    private struct Fixture {
        let store: FluxStore<WorkspaceFeature>
        let token: UUID
    }

    /// A fresh reducer state per scenario: the generation token guards stale work.
    private func makeFixture() -> Fixture {
        let state = WorkspaceFeature.State()
        return Fixture(store: FluxStore(state: state), token: state.generation)
    }

    private func tab(_ runtimeId: String, title: String, path: String? = nil,
                     activity: SessionActivity? = nil, project: String = "/repo") -> OpenSession {
        OpenSession(identity: OpenSessionIdentity(scope: scope, sessionPath: path,
                                                 runtimeId: runtimeId, projectPath: project),
                    title: title, activity: activity)
    }

    private func catalogue(_ statuses: [(String, String)]) -> PiCatalogue {
        .init(sessions: statuses.map {
            .init(sessionId: $0.0, title: $0.0, projectPath: "/repo", projectName: "repo", status: $0.1)
        })
    }

    @Test func openingTheSameHistoryOrRuntimeSelectsTheExistingTab() {
        let fixture = makeFixture()
        let store = fixture.store, token = fixture.token
        let first = tab("one", title: "Saved", path: "/history/saved")
        store.dispatch(.opened(token, first))
        let again = tab("one-rotated", title: "Saved again", path: "/history/saved")
        store.dispatch(.opened(token, again))
        #expect(store.state.openSessions.map(\.title) == ["Saved"])
        #expect(store.state.selectedSessionId == first.id)
        let restarted = tab("restarted", title: "Reopened runtime")
        store.dispatch(.opened(token, restarted))
        store.dispatch(.opened(token, tab("restarted", title: "Reopened again")))
        #expect(store.state.openSessions.count == 2)
        #expect(store.state.selectedSession?.runtimeId == "restarted")
    }

    @Test func openingASecondSessionKeepsBothTabsInOpenedOrder() {
        let fixture = makeFixture()
        let store = fixture.store, token = fixture.token
        let quick = tab("chat", title: "New chat", project: "/home/pi")
        let running = tab("running", title: "Working")
        store.dispatch(.opened(token, quick))
        store.dispatch(.opened(token, running))
        #expect(store.state.openSessionIds == [quick.id, running.id])
        #expect(store.state.selectedSessionId == running.id)
        store.dispatch(.selectRequested(id: quick.id))
        #expect(store.state.selectedSession?.title == "New chat")
        // Order is stable: selection never reorders tabs.
        #expect(store.state.openSessionIds == [quick.id, running.id])
    }

    @Test func switchingTabsKeepsEachDraftIsolated() {
        let fixture = makeFixture()
        let store = fixture.store, token = fixture.token
        let first = tab("one", title: "One"), second = tab("two", title: "Two")
        store.dispatch(.opened(token, first))
        store.dispatch(.opened(token, second))
        // The visible tab owns the composer text and the reading position.
        store.dispatch(.followTailChanged(false))
        store.dispatch(.scrollAnchorChanged("message-1"))
        store.dispatch(.draftChanged("Keep for two"))
        store.dispatch(.selectRequested(id: first.id))
        #expect(store.state.selectedSession?.draft == "")
        #expect(store.state.openSessions.first { $0.id == second.id }?.draft == "Keep for two")
        store.dispatch(.draftChanged("Keep for one"))
        #expect(store.state.openSessions.first { $0.id == first.id }?.draft == "Keep for one")
        #expect(store.state.openSessions.first { $0.id == first.id }?.followTail == true)
        #expect(store.state.openSessions.first { $0.id == first.id }?.scrollAnchor == nil)
        #expect(store.state.openSessions.first { $0.id == second.id }?.followTail == false)
        #expect(store.state.openSessions.first { $0.id == second.id }?.scrollAnchor == "message-1")
    }

    @Test func closingASelectedTabSelectsTheAdjacentTabAndDropsItsDraft() {
        let fixture = makeFixture()
        let store = fixture.store, token = fixture.token
        store.dispatch(.connectionChanged(token, .connected))
        let first = tab("one", title: "One"), second = tab("two", title: "Two"), third = tab("three", title: "Three")
        for value in [first, second, third] { store.dispatch(.opened(token, value)) }
        store.dispatch(.selectRequested(id: second.id))
        store.dispatch(.draftChanged("Discard me"))
        store.dispatch(.closeSession(second.id))
        #expect(store.state.openSessionIds == [first.id, third.id])
        #expect(store.state.selectedSessionId == third.id)
        store.dispatch(.selectRequested(id: first.id))
        store.dispatch(.draftChanged("Keep me"))
        store.dispatch(.closeSession(first.id))
        #expect(store.state.selectedSessionId == third.id)
        store.dispatch(.draftChanged("Last"))
        store.dispatch(.closeSession(third.id))
        #expect(store.state.openSessionIds.isEmpty)
        #expect(store.state.selectedSession == nil)
        #expect(store.state.isConnected)
    }

    @Test func closingABackgroundTabKeepsTheSelection() {
        let fixture = makeFixture()
        let store = fixture.store, token = fixture.token
        let first = tab("one", title: "One"), second = tab("two", title: "Two")
        store.dispatch(.opened(token, first))
        store.dispatch(.opened(token, second))
        store.dispatch(.closeSession(first.id))
        #expect(store.state.selectedSessionId == second.id)
        #expect(store.state.openSessionIds == [second.id])
    }

    @Test func catalogueActivityReachesTabsWithoutOtherEvents() {
        let fixture = makeFixture()
        let store = fixture.store, token = fixture.token
        let running = tab("running", title: "Working"), other = tab("idle", title: "Idle")
        store.dispatch(.opened(token, running))
        store.dispatch(.opened(token, other))
        store.dispatch(.catalogueChanged(token, catalogue([("running", "running"), ("idle", "idle")])))
        #expect(store.state.openSessions.first { $0.id == running.id }?.activity == .running)
        #expect(store.state.openSessions.first { $0.id == other.id }?.activity == nil)
        store.dispatch(.catalogueChanged(token, catalogue([("running", "blocked"), ("idle", "closing")])))
        #expect(store.state.openSessions.first { $0.id == running.id }?.activity == .needsYou)
        #expect(store.state.openSessions.first { $0.id == other.id }?.activity == .closing)
        #expect(store.state.openSessionIds == [running.id, other.id])
    }

    @Test func aReplacedRuntimeKeepsTabIdentityDraftAndOrder() {
        let fixture = makeFixture()
        let store = fixture.store, token = fixture.token
        let first = tab("one", title: "One"), second = tab("two", title: "Two")
        store.dispatch(.opened(token, first))
        store.dispatch(.draftChanged("Typed before the swap"))
        store.dispatch(.opened(token, second))
        store.dispatch(.sessionReplaced(first.id, "one-replacement"))
        #expect(store.state.openSessionIds == [first.id, second.id])
        #expect(store.state.openSessions.first?.runtimeId == "one-replacement")
        #expect(store.state.openSessions.first?.draft == "Typed before the swap")
        #expect(store.state.selectedSessionId == second.id)
    }

    @Test func aClosedRuntimeRemovesItsTabAndSelectsTheAdjacentOne() {
        let fixture = makeFixture()
        let store = fixture.store, token = fixture.token
        let first = tab("one", title: "One"), second = tab("two", title: "Two")
        store.dispatch(.opened(token, first))
        store.dispatch(.opened(token, second))
        store.dispatch(.sessionClosed(second.id))
        #expect(store.state.openSessionIds == [first.id])
        #expect(store.state.selectedSessionId == first.id)
        store.dispatch(.sessionClosed("unknown"))
        #expect(store.state.openSessionIds == [first.id])
    }
}
