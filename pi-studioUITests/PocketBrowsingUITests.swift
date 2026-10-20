import XCTest

final class PocketBrowsingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testConnectBrowsesWithoutCreatingAndUsesCompactHeader() {
        let app = PiUIDriver.launch(for: self)
        app.projects.connect()
        app.projects.shouldBeBrowsing()
        app.projects.shouldShowProject("pi-studio")
        app.projects.shouldHaveCompactHeader()
        app.projects.recordAppearance("Compact projects")
    }

    @MainActor func testQuickChatHistoryAndRunningSessionNavigation() {
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
        app.projects.back()
        app.projects.newProjectSession()
        app.session.waitUntilReady()
        app.chat.shouldAllowSend(false)
    }

    @MainActor func testRejectedOpenShowsErrorWithoutLeavingCatalogue() {
        let app = PiUIDriver.launch(for: self, rejectOpen: true)
        app.projects.connect()
        app.projects.openSavedQuickChat()
        app.session.shouldShowError()
        app.projects.shouldBeBrowsing()
    }
}
