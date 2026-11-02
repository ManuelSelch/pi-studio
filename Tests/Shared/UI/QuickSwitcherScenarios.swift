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

    func testClickingHomeSearchDoesNotExpandSwitcher() throws {
        try switcher.clickHomeSearch()

        try switcher.homeSearchShouldBeCollapsed()
    }

    func testTypingInHomeSearchKeepsTheCompleteQuery() throws {
        try switcher.clickHomeSearch()
        try switcher.typeOnHomeSearch("Quick Chats")

        try switcher.shouldBeInline()
        try switcher.searchShouldContain("Quick Chats")
        try switcher.shouldShowResult("Quick Chats", kind: "Folders")
    }

    func testHomeSearchExpandsInlineAndCollapses() throws {
        try switcher.homeShouldShowHeading("Let's cook")
        try switcher.homeSearchShouldBeCollapsed()
        try switcher.openFromHomeSearch()

        try switcher.shouldBeInline()
        try switcher.shouldShowRecentSessions()
        try switcher.dismiss()
        try switcher.homeSearchShouldBeCollapsed()
    }

    #if os(macOS)
    func testTypingOnHomeExpandsAndSearchesWithoutClicking() throws {
        try switcher.typeOnInitiallyFocusedHomeSearch("Quick Chats")

        try switcher.shouldBeInline()
        try switcher.searchShouldContain("Quick Chats")
        try switcher.shouldShowResult("Quick Chats", kind: "Folders")
    }

    func testReopeningHomeSwitcherPreservesSearchDraft() throws {
        try switcher.typeOnInitiallyFocusedHomeSearch("Quick Chats")
        try switcher.dismiss()
        try switcher.openUsingShortcut("k")

        try switcher.shouldBeInline()
        try switcher.searchShouldContain("Quick Chats")
        try switcher.shouldShowResult("Quick Chats", kind: "Folders")
    }

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

    func testSwitcherOmitsKeyboardHintLabels() throws {
        try switcher.openFromHomeSearch()

        try switcher.shouldHideKeyboardHints()
        try switcher.search("studio")
        try switcher.shouldHideResultsHeading()
        try switcher.dismissWithoutCloseButton()
    }

    func testFolderAndWorktreeResultsShowNamesWithoutPaths() throws {
        try switcher.openFromHomeSearch()
        try switcher.filter("Folders")
        try switcher.folderResultShouldHidePath("Quick Chats")

        try switcher.filter("Worktrees")
        try switcher.worktreeResultShouldShowRepository("pi-studio", branch: "feat/pocket")
        try switcher.worktreeResultShouldHidePath("feat/pocket")
    }

    #if os(macOS)
    func testShiftTabCyclesFiltersBackwards() throws {
        try switcher.openFromHomeSearch()
        try switcher.search("studio")
        try switcher.pressTab()
        try switcher.filterShouldBe("Folders", search: "studio")
        try switcher.pressShiftTab()
        try switcher.filterShouldBe("All", search: "studio")
        try switcher.pressShiftTab()
        try switcher.filterShouldBe("Actions", search: "studio")
        try switcher.pressTab()
        try switcher.filterShouldBe("All", search: "studio")
    }
    #endif

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

    #if os(macOS)
    func testOpeningSavedSessionFocusesComposerWithoutClicking() throws {
        try switcher.openFromHomeSearch()
        try switcher.selectSession("Saved quick chat")

        try switcher.shouldShowSession("Saved quick chat")
        try switcher.composerShouldRegainFocus()
    }

    func testCreatingSessionFocusesComposerWithoutClicking() throws {
        try switcher.openFromHomeSearch()
        try switcher.selectFolder("Quick Chats")

        try switcher.shouldShowNewSession(in: "Quick Chats")
        try switcher.composerShouldRegainFocus()
    }
    #endif

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
