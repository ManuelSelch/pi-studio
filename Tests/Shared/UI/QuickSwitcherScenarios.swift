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
        try switcher.homeSearchShouldBeCollapsed()
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

    func testSwitcherOmitsKeyboardHintLabels() throws {
        try switcher.openFromHomeSearch()

        try switcher.shouldHideKeyboardHints()
        try switcher.search("studio")
        try switcher.shouldHideResultsHeading()
        try switcher.dismissWithoutCloseButton()
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

}
