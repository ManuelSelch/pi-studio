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
        #expect(groups[1].sessions[0].activity == "Running")
    }

    @Test func unsavedRuntimesAppearEvenBeforeTheirProjectIsCatalogued() {
        let catalogue = PiCatalogue(sessions: [.init(sessionId: "new", title: "Unsaved", projectPath: "/new", projectName: "new")])
        let groups = ProjectListModel.groups(catalogue)
        #expect(groups.count == 1)
        #expect(groups[0].sessions[0].target == .runtime("new"))
    }

    @Test func missingProjectCannotCreateAndClosingRuntimeCannotOpen() {
        let groups = ProjectListModel.groups(.init(projects: [.init(path: "/gone", name: "gone", exists: false)],
            sessions: [.init(sessionId: "closing", title: "Closing", projectPath: "/gone", projectName: "gone", status: "closing")]))
        #expect(!groups[0].canCreate)
        #expect(!groups[0].sessions[0].canOpen)
    }
}
