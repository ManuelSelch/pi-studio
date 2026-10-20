import XCTest

final class pi_studioUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor private func launch(_ extra: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + (extra.map { [$0] } ?? [])
        app.launch()
        return app
    }
    @MainActor private func connect(_ app: XCUIApplication) {
        app.buttons["connectButton"].tap()
        let consent = app.alerts.buttons["Connect and take control"]
        XCTAssertTrue(consent.waitForExistence(timeout: 3))
        consent.tap()
        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 4))
    }
    @MainActor func testDisconnectedControlsAndTakeoverConsent() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Disconnected"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["sendButton"].isEnabled)
        XCTAssertFalse(app.buttons["stopButton"].isEnabled)
        app.buttons["connectButton"].tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Disconnected"].exists)
    }
    @MainActor func testTwoTurnsStreamingStopAndDisconnectRetention() throws {
        let app = launch()
        connect(app)
        let field = app.textFields["messageField"]
        field.tap(); field.typeText("Say hello")
        app.buttons["sendButton"].tap()
        let first = app.staticTexts["message-assistant-1"]
        XCTAssertTrue(first.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Generating…"].exists)
        XCTAssertFalse(app.buttons["sendButton"].isEnabled)
        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 5))
        XCTAssertEqual(first.label, "Hello from the demo. This reply is streaming a little at a time.")
        field.tap(); field.typeText("Second turn")
        app.buttons["sendButton"].tap()
        let second = app.staticTexts["message-assistant-2"]
        XCTAssertTrue(second.waitForExistence(timeout: 3))
        app.buttons["stopButton"].tap()
        XCTAssertTrue(app.staticTexts["Stopping…"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Ready"].waitForExistence(timeout: 4))
        XCTAssertFalse(second.label.isEmpty)
        let partial = second.label
        app.buttons["connectButton"].tap()
        XCTAssertTrue(app.staticTexts["Disconnected"].waitForExistence(timeout: 3))
        XCTAssertEqual(second.label, partial)
    }
    @MainActor func testActiveDisconnectWarnsWithoutDiscardingTranscript() throws {
        let app = launch()
        connect(app)
        let field = app.textFields["messageField"]
        field.tap(); field.typeText("Long answer")
        app.buttons["sendButton"].tap()
        XCTAssertTrue(app.staticTexts["message-assistant-1"].waitForExistence(timeout: 3))
        app.buttons["connectButton"].tap()
        let warning = app.alerts["Disconnect?"]
        XCTAssertTrue(warning.waitForExistence(timeout: 2))
        warning.buttons["Disconnect"].tap()
        XCTAssertTrue(app.staticTexts["Disconnected"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["message-assistant-1"].exists)
    }
    @MainActor func testUnknownSendOutcomeRetainsDraftAndDisablesResend() throws {
        let app = launch("--ui-send-unknown")
        connect(app)
        let field = app.textFields["messageField"]
        field.tap(); field.typeText("Keep uncertain draft")
        app.buttons["sendButton"].tap()
        XCTAssertTrue(app.staticTexts["Outcome unknown"].waitForExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "Keep uncertain draft")
        XCTAssertFalse(app.buttons["sendButton"].isEnabled)
        XCTAssertTrue(app.staticTexts["errorMessage"].exists)
    }
    @MainActor func testRejectedSendRetainsDraftAndShowsError() throws {
        let app = launch("--ui-send-rejected")
        connect(app)
        let field = app.textFields["messageField"]
        field.tap(); field.typeText("Keep draft")
        app.buttons["sendButton"].tap()
        XCTAssertTrue(app.staticTexts["errorMessage"].waitForExistence(timeout: 3))
        XCTAssertEqual(field.value as? String, "Keep draft")
        XCTAssertTrue(app.staticTexts["Ready"].exists)
    }
}
