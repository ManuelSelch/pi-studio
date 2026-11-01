import XCTest

/// Acceptance drafts: driver mechanics deliberately fail until implementation begins.
@MainActor
final class QuickSwitcherScenarios: XCTestCase {
    private var app: PiUIDriver!
    private var switcher: QuickSwitcherDraftDriver!

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = PiUIDriver.launch(for: self, automaticallyConnect: true)
        switcher = QuickSwitcherDraftDriver(app)
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

    func testSelectingFolderAndWorktreeCreatesNewSessions() throws {
        try switcher.openFromHomeSearch()
        try switcher.selectFolder("Quick Chats")
        try switcher.shouldShowNewSession(in: "Quick Chats")

        try switcher.returnHome()
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
        try switcher.shouldShowOneOpenSession("Saved quick chat")
    }
}

/// Explicitly incomplete; no selectors or assertions are claimed by these drafts.
@MainActor
private final class QuickSwitcherDraftDriver {
    private enum DraftError: Error { case notImplemented }
    init(_ app: PiUIDriver) {}
    func homeShouldShowHeading(_ text: String) throws { throw DraftError.notImplemented }
    func openFromHomeSearch() throws { throw DraftError.notImplemented }
    func shouldBeInline() throws { throw DraftError.notImplemented }
    func shouldBeDialog() throws { throw DraftError.notImplemented }
    func shouldShowRecentSessions() throws { throw DraftError.notImplemented }
    func dismiss() throws { throw DraftError.notImplemented }
    func homeSearchShouldBeCollapsed() throws { throw DraftError.notImplemented }
    func openUsingShortcut(_ key: String) throws { throw DraftError.notImplemented }
    func composerShouldRegainFocus() throws { throw DraftError.notImplemented }
    func filter(_ name: String) throws { throw DraftError.notImplemented }
    func search(_ text: String) throws { throw DraftError.notImplemented }
    func shouldShowResult(_ title: String, kind: String) throws { throw DraftError.notImplemented }
    func shouldShowNoActions() throws { throw DraftError.notImplemented }
    func selectFolder(_ name: String) throws { throw DraftError.notImplemented }
    func selectWorktree(_ name: String) throws { throw DraftError.notImplemented }
    func shouldShowNewSession(in context: String) throws { throw DraftError.notImplemented }
    func returnHome() throws { throw DraftError.notImplemented }
    func selectSession(_ title: String) throws { throw DraftError.notImplemented }
    func openFromSession() throws { throw DraftError.notImplemented }
    func shouldShowSession(_ title: String) throws { throw DraftError.notImplemented }
    func shouldShowOneOpenSession(_ title: String) throws { throw DraftError.notImplemented }
}
