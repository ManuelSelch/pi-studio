import XCTest

/// Acceptance scenarios for the approved session-header mockup.
#if os(macOS)
final class SessionHeaderScenarios: XCTestCase {
    @MainActor private lazy var app = PiUIDriver.launch(for: self)
    @MainActor private lazy var header = SessionHeaderDraftDriver()

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testSelectedSessionShowsProjectTitleAndStatusWithoutPath() throws {
        app.projects.connect()
        app.projects.openRunningSession()

        try header.shouldShowProjectAndSessionTitleWithStatus()
        try header.shouldHideProjectPathAndPiStudioHeading()
        try header.shouldShowIconOnlySettingsAndSendWithoutShortcutHint()
    }

    @MainActor func testCloseLeavesRunningSessionAvailableInBackground() throws {
        app.projects.connect()
        app.projects.openRunningSession()

        try header.closeSession()
        try header.shouldCloseConversation()
        try header.shouldOfferRunningSessionInInbox()
        app.projects.openRunningSession()
        app.session.statusShouldBe("Generating…")
    }

    @MainActor func testMoveToLaterCanBeResumed() throws {
        app.projects.connect()
        app.projects.openSavedQuickChat()

        try header.moveToLater()
        app.projects.expandLater()
        app.projects.shouldOfferQuickChatInLater()
        app.projects.resumeQuickChatFromLater()
        app.projects.shouldShowSavedAnswer()
    }

    @MainActor func testNewSessionUsesCurrentProject() throws {
        app.projects.connect()
        app.projects.openRunningSession()

        try header.createSession()
        try header.shouldShowNewSessionInCurrentProject()
    }
}

@MainActor private struct SessionHeaderDraftDriver {
    private var app: XCUIApplication { XCUIApplication() }

    func shouldShowProjectAndSessionTitleWithStatus() throws {
        XCTAssertTrue(app.staticTexts["sessionTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sessionTitle"].value as? String, "Pocket navigation")
        XCTAssertEqual(app.staticTexts["sessionContext"].value as? String, "pi-studio")
        XCTAssertTrue(app.descendants(matching: .any)["headerStatus"].exists)
    }
    func shouldHideProjectPathAndPiStudioHeading() throws {
        XCTAssertFalse(app.staticTexts["/repo"].exists)
        XCTAssertNotEqual(app.staticTexts["sessionTitle"].value as? String, "Pi Studio")
    }
    func shouldShowIconOnlySettingsAndSendWithoutShortcutHint() throws {
        XCTAssertTrue(app.buttons["settingsButton"].exists)
        XCTAssertTrue(app.buttons["sendButton"].exists)
        XCTAssertFalse(app.staticTexts["Enter to send · Shift + Enter for a new line"].exists)
    }
    func closeSession() throws { app.buttons["headerClose"].tap() }
    func shouldCloseConversation() throws {
        XCTAssertTrue(app.staticTexts["sessionTitle"].waitForNonExistence(timeout: 5))
    }
    func shouldOfferRunningSessionInInbox() throws {
        XCTAssertTrue(app.buttons["inbox-runtime:ui-running"].waitForExistence(timeout: 5))
    }
    func moveToLater() throws { try tapEnabled("headerLater") }
    private func tapEnabled(_ identifier: String) throws {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled, "\(identifier) must be enabled")
        button.tap()
    }
    func createSession() throws { app.buttons["headerNew"].tap() }
    func shouldShowNewSessionInCurrentProject() throws {
        let title = app.staticTexts["sessionTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "value == %@", "New session")
        expectationForTitle(predicate, title)
        XCTAssertEqual(app.staticTexts["sessionContext"].value as? String, "pi-studio")
    }
    private func expectationForTitle(_ predicate: NSPredicate, _ title: XCUIElement) {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
}
#endif
