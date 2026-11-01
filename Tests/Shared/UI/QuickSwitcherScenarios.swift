import XCTest

/// End-to-end quick-switcher journeys through the semantic UI driver.
@MainActor
final class QuickSwitcherScenarios: XCTestCase {
    private var app: PiUIDriver!
    private var switcher: UIQuickSwitcherDriver!

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = PiUIDriver.launch(for: self, automaticallyConnect: true)
        switcher = app.quickSwitcher
    }

    func testHomeSearchExpandsInlineAndCollapses() throws {
        try switcher.homeShouldShowHeading("Let's cook")
        try switcher.openFromHomeSearch()

        try switcher.shouldBeInline()
        try switcher.shouldShowRecentSessions()
        try switcher.dismiss()
        try switcher.homeSearchShouldBeCollapsed()
    }

    #if os(macOS)
    func testBothShortcutsOpenSwitcherOnHomeAndSession() throws {
        try switcher.openUsingShortcut("k")
        try switcher.shouldBeInline()
        try switcher.dismiss()
        try switcher.openUsingShortcut("o")
        try switcher.shouldBeInline()
        try switcher.dismiss()

        app.projects.openSavedQuickChat()
        try switcher.focusComposer()
        try switcher.openUsingShortcut("k")
        try switcher.shouldBeDialog()
        try switcher.dismiss()
        try switcher.openUsingShortcut("o")
        try switcher.shouldBeDialog()
        try switcher.dismiss()
        try switcher.composerShouldRegainFocus()
    }
    #endif

    func testFiltersSearchAndEmptyActions() throws {
        try switcher.openFromHomeSearch()
        try switcher.filter("Folders")
        try switcher.search("Quick Chats")
        try switcher.shouldShowResult("Quick Chats", kind: "Folders")
        try switcher.filter("Worktrees")
        try switcher.search("feat/pocket")
        try switcher.shouldShowResult("feat/pocket", kind: "Worktrees")
        try switcher.filter("Sessions")
        try switcher.search("Saved quick chat")
        try switcher.shouldShowResult("Saved quick chat", kind: "Sessions")
        try switcher.filter("Actions")
        try switcher.shouldShowNoActions()
    }

    func testSelectingFolderCreatesNewSession() throws {
        try switcher.openFromHomeSearch()
        try switcher.selectFolder("Quick Chats")
        try switcher.shouldShowNewSession(in: "Quick Chats")
    }

    func testSelectingWorktreeCreatesNewSession() throws {
        try switcher.openFromHomeSearch()
        try switcher.selectWorktree("feat/pocket")
        try switcher.shouldShowNewSession(in: "feat/pocket")
    }

    func testSelectingSessionOpensAndRefocusesExistingSession() throws {
        try switcher.openFromHomeSearch()
        try switcher.selectSession("Saved quick chat")
        try switcher.shouldShowSession("Saved quick chat")

        try switcher.openFromSession()
        try switcher.selectSession("Saved quick chat")
        try switcher.shouldShowSession("Saved quick chat")
        #if os(iOS)
        try switcher.shouldShowOneOpenSession("Saved quick chat")
        #endif
        // Mac deduplication is asserted at the workspace boundary in WorkspaceTabsTests.
    }
}
