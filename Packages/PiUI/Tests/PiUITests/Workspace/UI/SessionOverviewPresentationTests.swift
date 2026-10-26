import Foundation
import PiSDK
import Testing
@testable import PiUI

/// Slice 3: the phone switches open sessions through an overview instead of a tab strip, and
/// the same value backs the Mac popover. These are the mapping rules both shells depend on.
@MainActor
struct SessionOverviewPresentationTests {
    private func catalogue(_ projects: [(path: String, name: String, quick: Bool)]) -> PiCatalogue {
        PiCatalogue(projects: projects.map {
            PiProjectSummary(path: $0.path, name: $0.name, quickChats: $0.quick)
        })
    }

    private func workspace(_ sessions: [OpenSession], selected: String?) -> WorkspaceFeature.State {
        var state = WorkspaceFeature.State()
        state.openSessions = sessions
        state.selectedSessionId = selected
        return state
    }

    private func session(_ id: String, _ title: String, project: String,
                         path: String? = nil, activity: SessionActivity? = nil,
                         unread: Bool = false) -> OpenSession {
        var session = OpenSession(identity: OpenSessionIdentity(scope: "s", sessionPath: path,
                                                               runtimeId: id, projectPath: project),
                                  title: title, activity: activity)
        session.unread = unread
        return session
    }

    @Test func openSessionsKeepTheirOrderTitleProjectAndSelection() {
        let sessions = [
            session("a", "New chat", project: "/home/pi"),
            session("b", "Working", project: "/repo", activity: .running, unread: true),
            session("c", "Saved", project: "/repo", activity: .needsYou)
        ]
        let state = workspace(sessions, selected: sessions[1].id)

        let rows = WorkspaceContainer.openSessions(state)
        #expect(rows.map(\.id) == sessions.map(\.id))
        #expect(rows.map(\.title) == ["New chat", "Working", "Saved"])
        #expect(rows.map(\.context) == ["/home/pi", "/repo", "/repo"])
        #expect(rows.map(\.isSelected) == [false, true, false])
        #expect(rows.map(\.unread) == [false, true, false])
        #expect(rows.map(\.activity) == [nil, .running, .needsYou])
    }

    /// Browsing projects is a real state, not an empty overview.
    @Test func noOpenSessionsMeansNoRows() {
        #expect(WorkspaceContainer.openSessions(workspace([], selected: nil)).isEmpty)
    }

    @Test func theNewSessionActionPrefersQuickChats() {
        let catalogue = catalogue([("/repo", "pi-studio", false), ("/home/pi", "Quick Chats", true)])
        #expect(WorkspaceContainer.newSessionPath(catalogue) == "/home/pi")
    }

    @Test func theNewSessionActionFallsBackToTheFirstProject() {
        #expect(WorkspaceContainer.newSessionPath(catalogue([("/repo", "pi-studio", false)])) == "/repo")
        #expect(WorkspaceContainer.newSessionPath(PiCatalogue()) == nil)
    }
}
