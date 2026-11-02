import XCTest

/// Session inbox navigation: all status groups replace project/history browsing.
final class WorkspaceBrowsingUITests: XCTestCase {
    @MainActor private lazy var app = PiUIDriver.launch(for: self)

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testConnectShowsSessionGroupsWithoutProjectHistory() throws {
        app.projects.connect()
        app.projects.shouldBeBrowsing()
        app.projects.shouldHaveInboxGroup("Ready")
        app.projects.shouldHaveInboxGroup("Running")
        app.projects.shouldNotShowProjectHistory()
        app.projects.shouldHaveCompactHeader()
        app.projects.recordAppearance("Session inbox")
        try app.projects.shouldShowNewSessionWithoutHeading()
        app.projects.openSavedQuickChat()
        app.projects.shouldShowSavedAnswer()
    }

    @MainActor func testReadyAndRunningSessionsOpenFromTheirInboxGroups() {
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
}
