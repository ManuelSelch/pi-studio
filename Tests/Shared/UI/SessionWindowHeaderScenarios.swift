import XCTest

#if os(macOS)
/// Acceptance scenarios for the approved native window-header layout.
final class SessionWindowHeaderScenarios: XCTestCase {
    private var rejectArchive = false
    @MainActor private lazy var app = PiUIDriver.launch(for: self, rejectArchive: rejectArchive)
    @MainActor private lazy var header = SessionWindowHeaderDraftDriver()

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testTitleAndActionsMoveToWindowToolbar() throws {
        app.projects.connect()
        app.projects.openRunningSession()

        try header.shouldShowProjectAndSessionInWindowToolbar()
        try header.shouldShowStatusAndSessionActionsInWindowToolbar()
        try header.shouldNotShowDuplicateSessionHeaderOrPiStudioTitle()
        try header.shouldShowStatusIndicatorWithoutVisibleName()
        try header.shouldShowAccessibleComposerWithoutMessageLabel()
        try header.shouldShowIconOnlySettingsAndSendWithoutShortcutHint()
    }

    @MainActor func testErrorAndTranscriptHaveSpaceBelowToolbar() throws {
        rejectArchive = true
        app.projects.connect()
        app.projects.openSavedQuickChat()
        try header.archiveSession()
        app.session.shouldShowError()

        try header.errorShouldBeInsetBelowToolbarDivider()
        try header.transcriptShouldBeInsetBelowToolbarDivider()
    }

    @MainActor func testWindowToolbarPreservesSessionActions() throws {
        app.projects.connect()
        app.projects.openRunningSession()

        try header.closeRunningSessionFromWindowToolbar()
        try header.shouldOfferRunningSessionInInbox()
        app.projects.openRunningSession()
        app.session.statusShouldBe("Generating…")
        try header.createSessionInCurrentProjectFromWindowToolbar()
    }
}

@MainActor private struct SessionWindowHeaderDraftDriver {
    private var app: XCUIApplication { XCUIApplication() }
    private var toolbar: XCUIElement { app.windows.firstMatch.toolbars.firstMatch }

    func shouldShowProjectAndSessionInWindowToolbar() throws {
        XCTAssertTrue(toolbar.waitForExistence(timeout: 5))
        XCTAssertTrue(toolbar.staticTexts["sessionTitle"].waitForExistence(timeout: 5))
        XCTAssertEqual(toolbar.staticTexts["sessionContext"].value as? String, "pi-studio")
        XCTAssertEqual(toolbar.staticTexts["sessionTitle"].value as? String, "Pocket navigation")
        XCTAssertLessThan(toolbar.staticTexts["sessionContext"].frame.minX, toolbar.frame.midX)
    }
    func shouldShowStatusAndSessionActionsInWindowToolbar() throws {
        for (id, label) in [("headerLater", "Move to Later"), ("headerArchive", "Archive session"),
                            ("headerClose", "Close session"), ("headerNew", "New session")] {
            XCTAssertTrue(toolbar.buttons[id].exists, "Missing \(id) in window toolbar")
            XCTAssertEqual(toolbar.buttons[id].label, label)
        }
        XCTAssertTrue(toolbar.descendants(matching: .any)["headerStatus"].exists)
    }
    func shouldShowStatusIndicatorWithoutVisibleName() throws {
        let indicator = toolbar.descendants(matching: .any)["headerStatus"]
        XCTAssertTrue(indicator.waitForExistence(timeout: 5))
        let status = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Generating…"), object: indicator)
        XCTAssertEqual(XCTWaiter.wait(for: [status], timeout: 5), .completed)
        XCTAssertFalse(toolbar.staticTexts["sessionStatus"].exists)
    }
    func shouldNotShowDuplicateSessionHeaderOrPiStudioTitle() throws {
        XCTAssertEqual(app.staticTexts.matching(identifier: "sessionTitle").count, 1)
        XCTAssertFalse(toolbar.staticTexts["Pi Studio"].exists)
    }
    func shouldShowAccessibleComposerWithoutMessageLabel() throws {
        let field = app.descendants(matching: .any).matching(identifier: "messageField").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.label, "Message")
        XCTAssertFalse(app.staticTexts["Message"].exists)
    }
    func shouldShowIconOnlySettingsAndSendWithoutShortcutHint() throws {
        XCTAssertTrue(app.buttons["settingsButton"].exists)
        XCTAssertTrue(app.buttons["sendButton"].exists)
        XCTAssertFalse(app.staticTexts["Enter to send · Shift + Enter for a new line"].exists)
        XCTAssertFalse(app.staticTexts["/repo"].exists)
    }
    func errorShouldBeInsetBelowToolbarDivider() throws {
        let error = app.staticTexts["errorMessage"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(error.frame.minY - toolbar.frame.maxY, 8)
    }
    func transcriptShouldBeInsetBelowToolbarDivider() throws {
        let message = app.descendants(matching: .any).matching(identifier: "message-saved-answer").firstMatch
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(message.frame.minY - toolbar.frame.maxY, 8)
    }
    func archiveSession() throws { toolbar.buttons["headerArchive"].tap() }
    func closeRunningSessionFromWindowToolbar() throws {
        toolbar.buttons["headerClose"].tap()
        XCTAssertTrue(app.staticTexts["sessionTitle"].waitForNonExistence(timeout: 5))
    }
    func shouldOfferRunningSessionInInbox() throws {
        XCTAssertTrue(app.buttons["inbox-runtime:ui-running"].waitForExistence(timeout: 5))
    }
    func createSessionInCurrentProjectFromWindowToolbar() throws {
        toolbar.buttons["headerNew"].tap()
        let title = toolbar.staticTexts["sessionTitle"]
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "New session"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
        XCTAssertEqual(toolbar.staticTexts["sessionContext"].value as? String, "pi-studio")
    }
}
#endif
