import XCTest

/// Session inbox navigation: all status groups replace project/history browsing.
final class WorkspaceBrowsingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testConnectShowsSessionGroupsWithoutProjectHistory() {
        let app = PiUIDriver.launch(for: self)
        app.projects.connect()
        app.projects.shouldBeBrowsing()
        app.projects.shouldHaveInboxGroup("Ready")
        app.projects.shouldHaveInboxGroup("Running")
        app.projects.shouldNotShowProjectHistory()
        app.projects.shouldHaveCompactHeader()
        app.projects.recordAppearance("Session inbox")
    }

    @MainActor func testReadyAndRunningSessionsOpenFromTheirInboxGroups() {
        let app = PiUIDriver.launch(for: self)
        app.projects.connect()
        app.projects.openSavedQuickChat()
        app.projects.shouldShowSavedAnswer()
        app.projects.recordAppearance("Saved Quick Chat")
        #if os(iOS)
        app.projects.back()
        app.projects.shouldBeBrowsing()
        #else
        app.projects.shouldNotShowProjectHistory()
        app.projects.shouldShowSavedAnswer()
        #endif
        app.projects.openRunningSession()
        app.session.statusShouldBe("Generating…")
    }

    @MainActor func testSavedReadySessionCanMoveToLaterAndResume() {
        let app = PiUIDriver.launch(for: self)
        app.projects.connect()
        app.projects.moveQuickChatToLater()
        app.projects.expandLater()
        app.projects.shouldOfferQuickChatInLater()
        app.projects.resumeQuickChatFromLater()
        app.projects.shouldShowSavedAnswer()
    }

    @MainActor func testRejectedOpenKeepsTheInboxVisible() {
        let app = PiUIDriver.launch(for: self, rejectOpen: true)
        app.projects.connect()
        app.projects.openSavedQuickChat()
        app.session.shouldShowError()
        app.projects.shouldBeBrowsing()
    }
}
