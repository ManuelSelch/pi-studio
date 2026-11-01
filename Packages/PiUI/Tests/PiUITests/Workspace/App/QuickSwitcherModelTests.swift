import Testing
import PiSDK
@testable import PiUI

@Suite struct QuickSwitcherModelTests {
    @Test func emptySearchShowsRecentSessionsOnly() {
        let catalogue = PiCatalogue(projects: [
            .init(path: "/repo", name: "studio", sessions: [
                .init(path: "/old", title: "Older", modified: 1),
                .init(path: "/new", title: "Recent", modified: 2)
            ])
        ])

        let items = QuickSwitcherModel.results(catalogue: catalogue, query: "")

        #expect(items.map(\.title) == ["Recent", "Older"])
    }

    @Test func scopesFilterFoldersWorktreesAndSessions() {
        let catalogue = PiCatalogue(projects: [
            .init(path: "/repo", name: "studio"),
            .init(path: "/worktree", name: "studio", worktree: .init(branch: "feature", primary: false),
                  sessions: [.init(path: "/session", title: "Fix bug")])
        ])

        #expect(QuickSwitcherModel.results(catalogue: catalogue, query: "#studio").map(\.kind) == [.folder])
        #expect(QuickSwitcherModel.results(catalogue: catalogue, query: "%feature").map(\.kind) == [.worktree])
        #expect(QuickSwitcherModel.results(catalogue: catalogue, query: "@bug").map(\.kind) == [.session])
        #expect(QuickSwitcherModel.results(catalogue: catalogue, query: "/").isEmpty)
    }
}
