import XCTest

/// Compact workspace browsing: connect lists projects without creating anything.
final class WorkspaceBrowsingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testConnectBrowsesWithoutCreatingASession() {
        let app = PiUIDriver.launch(for: self)
        app.projects.connect()
        app.projects.shouldBeBrowsing()
        app.projects.shouldShowProject("pi-studio")
        app.projects.shouldHaveCompactHeader()
        app.projects.recordAppearance("Compact workspace browse")
    }

    @MainActor func testQuickChatAndRunningSessionNavigation() {
        let app = PiUIDriver.launch(for: self)
        app.projects.connect()
        app.projects.openSavedQuickChat()
        app.projects.shouldShowSavedAnswer()
        app.projects.recordAppearance("Saved Quick Chat")
        app.projects.back()
        app.projects.shouldBeBrowsing()
        app.projects.expandProject("pi-studio")
        app.projects.openRunningSession()
        app.session.statusShouldBe("Generating…")
    }

    @MainActor func testRejectedOpenKeepsTheCatalogueVisible() {
        let app = PiUIDriver.launch(for: self, rejectOpen: true)
        app.projects.connect()
        app.projects.openSavedQuickChat()
        app.session.shouldShowError()
        app.projects.shouldBeBrowsing()
    }
}
