import XCTest

/// Acceptance scenarios for the approved session-header mockup.
#if os(macOS)
final class SessionHeaderScenarios: XCTestCase {
    @MainActor private lazy var app = PiUIDriver.launch(for: self)
    @MainActor private lazy var header = SessionHeaderDraftDriver()

    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testMoveToLaterCanBeResumed() throws {
        app.projects.connect()
        app.projects.openSavedQuickChat()

        try header.moveToLater()
        app.projects.expandLater()
        app.projects.shouldOfferQuickChatInLater()
        app.projects.resumeQuickChatFromLater()
        app.projects.shouldShowSavedAnswer()
    }

}

@MainActor private struct SessionHeaderDraftDriver {
    private var app: XCUIApplication { XCUIApplication() }

    func moveToLater() throws { try tapEnabled("headerLater") }
    private func tapEnabled(_ identifier: String) throws {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isEnabled, "\(identifier) must be enabled")
        button.tap()
    }
}
#endif
