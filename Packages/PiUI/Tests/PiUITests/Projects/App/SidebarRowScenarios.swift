import Testing
import PiSDK
import PiUI

@Suite struct SidebarRowScenarios {
    private let sidebar: SidebarRowDriver

    init() {
        sidebar = SidebarRowDriver()
    }

    @Test func sessionWithoutWorktreeShowsProjectAndTitle() throws {
        try sidebar.addSession(id: "research", project: "Quick Chats", worktree: nil, title: "Research")

        try sidebar.shouldShowLines(["Quick Chats", "Research"], forSession: "research")
    }

    @Test func primaryCheckoutHidesItsBranchName() throws {
        try sidebar.addSession(id: "primary", project: "pi-studio", worktree: "main", primary: true, title: "Fix tests")

        try sidebar.shouldShowLines(["pi-studio", "Fix tests"], forSession: "primary")
    }

    @Test func singleSessionInWorktreeShowsProjectAndWorktree() throws {
        try sidebar.addSession(id: "layout", project: "pi-studio", worktree: "feat/sidebar", title: "Refine layout")

        try sidebar.shouldShowLines(["pi-studio", "feat/sidebar"], forSession: "layout")
    }

    @Test func sessionsInSameWorktreeShowTheirTitlesAcrossInboxGroups() throws {
        try sidebar.addSession(id: "first", project: "pi-studio", worktree: "feat/sidebar", title: "First")
        try sidebar.addSession(id: "second", project: "pi-studio", worktree: "feat/sidebar", title: "Second", later: true)

        try sidebar.shouldShowLines(["pi-studio", "feat/sidebar", "First"], forSession: "first")
        try sidebar.shouldShowLines(["pi-studio", "feat/sidebar", "Second"], forSession: "second")
    }

    @Test func duplicateSessionTitlesAreAddressedByIdentity() throws {
        try sidebar.addSession(id: "one", project: "alpha", worktree: nil, title: "Untitled")
        try sidebar.addSession(id: "two", project: "beta", worktree: nil, title: "Untitled")

        try sidebar.shouldShowLines(["alpha", "Untitled"], forSession: "one")
        try sidebar.shouldShowLines(["beta", "Untitled"], forSession: "two")
    }

    @Test func identicallyNamedWorktreesInDifferentProjectsRemainIndependent() throws {
        try sidebar.addSession(id: "first", project: "alpha", worktree: "feat/sidebar", title: "First")
        try sidebar.addSession(id: "second", project: "beta", worktree: "feat/sidebar", title: "Second")

        try sidebar.shouldShowLines(["alpha", "feat/sidebar"], forSession: "first")
        try sidebar.shouldShowLines(["beta", "feat/sidebar"], forSession: "second")
    }
}

private final class SidebarRowDriver {
    private struct Entry {
        let id: String
        let project: String
        let worktree: String?
        let primary: Bool
        let title: String
        let later: Bool
    }
    private var entries: [Entry] = []

    func addSession(id: String, project: String, worktree: String?, primary: Bool = false, title: String, later: Bool = false) throws {
        entries.append(Entry(id: id, project: project, worktree: worktree, primary: primary, title: title, later: later))
    }

    func shouldShowLines(_ lines: [String], forSession id: String) throws {
        let checkouts = Dictionary(grouping: entries) { "\($0.project)/\($0.primary ? "primary" : ($0.worktree ?? "primary"))" }
        let projects: [PiProjectSummary] = checkouts.map { path, entries in
            let first = entries[0]
            return .init(path: path, name: first.project, repositoryPath: first.project, repositoryName: first.project,
                         worktree: first.worktree.map { .init(branch: $0, primary: first.primary) },
                         sessions: entries.map { .init(path: $0.id, title: $0.title) })
        }
        let sessions = SessionInboxModel.sessions(.init(projects: projects), laterPaths: Set(entries.filter(\.later).map(\.id)))
        let session = try #require(sessions.first { $0.id == id })
        #expect(session.displayLines == lines)
    }
}
