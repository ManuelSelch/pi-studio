import Foundation
import Testing
import PiSDK
import PiUI

@Suite struct ProjectListModelTests {
    @Test func quickChatsFirstAndWorktreeSessionsGroupUnderRepository() {
        let catalogue = PiCatalogue(projects: [
            .init(path: "/repo", name: "repo", repositoryPath: "/repo", sessions: [.init(path: "/h/main", title: "Main chat", modified: 1)]),
            .init(path: "/tree", name: "tree", repositoryPath: "/repo", repositoryName: "repo",
                  worktree: .init(branch: "feat/pocket", primary: false),
                  sessions: [.init(path: "/h/tree", title: "Pocket", modified: 2), .init(path: "/h/archived", title: "Hidden", archivedAt: 1)]),
            .init(path: "/home/pi", name: "Quick Chats", quickChats: true),
        ], sessions: [.init(sessionId: "live", title: "Pocket", sessionPath: "/h/tree", projectPath: "/tree", projectName: "tree", status: "running")])
        let groups = ProjectListModel.groups(catalogue)
        #expect(groups.map(\.name) == ["Quick Chats", "repo"])
        #expect(groups[1].newSessionPath == "/repo")
        #expect(groups[1].sessions.map(\.title) == ["Pocket", "Main chat"])
        #expect(groups[1].sessions[0].target == .runtime("live"))
        #expect(groups[1].sessions[0].detail == "feat/pocket")
        #expect(groups[1].sessions[0].activity == .running)
    }

    @Test func blockedRuntimeIsReportedAsNeedsYou() {
        let catalogue = PiCatalogue(
            projects: [.init(path: "/repo", name: "repo")],
            sessions: [.init(sessionId: "waiting", title: "Waiting", projectPath: "/repo", projectName: "repo", status: "blocked")])
        let groups = ProjectListModel.groups(catalogue)
        #expect(groups[0].sessions[0].activity == .needsYou)
        #expect(groups[0].sessions[0].canOpen)
    }

    @Test func unsavedRuntimesAppearEvenBeforeTheirProjectIsCatalogued() {
        let catalogue = PiCatalogue(sessions: [.init(sessionId: "new", title: "Unsaved", projectPath: "/new", projectName: "new")])
        let groups = ProjectListModel.groups(catalogue)
        #expect(groups.count == 1)
        #expect(groups[0].sessions[0].target == .runtime("new"))
    }

    @Test func inboxGroupsBlockedIdleRunningAndLaterSavedSessionsWithoutProjectHistory() {
        let catalogue = PiCatalogue(projects: [
            .init(path: "/repo", name: "repo", sessions: [
                .init(path: "/history/ready", title: "Idle history", modified: 3),
                .init(path: "/history/archived", title: "Archived", archivedAt: 4),
                .init(path: "/history/later", title: "Parked", modified: 2),
            ])
        ], sessions: [
            .init(sessionId: "blocked", title: "Needs input", sessionPath: "/history/ready", projectPath: "/repo", projectName: "repo", status: "blocked"),
            .init(sessionId: "running", title: "Working", projectPath: "/repo", projectName: "repo", status: "running"),
        ])

        let rows = SessionInboxModel.sessions(catalogue, laterPaths: ["/history/later"])

        #expect(rows.first { $0.row.title == "Needs input" }?.status == .needsYou)
        #expect(rows.first { $0.row.title == "Parked" }?.status == .later)
        #expect(rows.first { $0.row.title == "Working" }?.status == .running)
        #expect(!rows.contains { $0.row.title == "Archived" })
        #expect(rows.first { $0.row.title == "Parked" }?.canMoveLater == false)
    }

    @Test func inboxIncludesUnopenedSavedIdleHistoryAndAllowsOnlySavedReadyToMoveLater() {
        let catalogue = PiCatalogue(projects: [.init(path: "/repo", name: "repo", sessions: [
            .init(path: "/history/ready", title: "Unopened idle", modified: 2)
        ])])

        let row = SessionInboxModel.sessions(catalogue, laterPaths: []).first

        #expect(row?.row.target == .history("/history/ready"))
        #expect(row?.status == .ready)
        #expect(row?.canMoveLater == true)
    }

    @MainActor @Test func laterMembershipIsLocalAndScopedToNormalizedEndpoint() {
        let defaults = UserDefaults(suiteName: "PiUI.Later.\(UUID().uuidString)")!
        let service = UserDefaultsLaterSessionsService(defaults: defaults)
        let first = URL(string: "WS://Example.COM:80/ws")!
        let equivalent = URL(string: "ws://example.com/ws")!
        let other = URL(string: "ws://example.com/other")!

        service.save(["/history/one"], endpoint: first)

        #expect(service.load(endpoint: equivalent) == ["/history/one"])
        #expect(service.load(endpoint: other).isEmpty)
    }

    @Test func missingProjectCannotCreateAndClosingRuntimeCannotOpen() {
        let groups = ProjectListModel.groups(.init(projects: [.init(path: "/gone", name: "gone", exists: false)],
            sessions: [.init(sessionId: "closing", title: "Closing", projectPath: "/gone", projectName: "gone", status: "closing")]))
        #expect(!groups[0].canCreate)
        #expect(!groups[0].sessions[0].canOpen)
    }
}
