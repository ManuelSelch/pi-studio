import XCTest

/// Session inbox gestures and rendered assertions; independent of integration mechanics.
@MainActor final class UIProjectsDriver {
    private let app: XCUIApplication
    init(_ app: XCUIApplication) { self.app = app }
    func connect(file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["connectButton"].tap()
        let consent = confirmation.buttons["Connect and take control"]
        XCTAssertTrue(consent.waitForExistence(timeout: 4), file: file, line: line)
        consent.tap()
        shouldBeBrowsing(file: file, line: line)
    }
    private var confirmation: XCUIElement {
        #if os(macOS)
        app.sheets.firstMatch
        #else
        app.alerts.firstMatch
        #endif
    }
    func shouldHaveInboxGroup(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), file: file, line: line)
    }
    func shouldNotShowProjectHistory(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.staticTexts["Projects & history"].exists, file: file, line: line)
    }
    func shouldBeBrowsing(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["inbox-/history/quick"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "messageField").firstMatch.exists, file: file, line: line)
    }
    func shouldShowNewSessionWithoutHeading(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(app.buttons["newInboxSession"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertFalse(app.staticTexts["Sessions"].exists, file: file, line: line)
        #if os(macOS)
        XCTAssertFalse(app.staticTexts["Pi Studio"].exists, file: file, line: line)
        #endif
    }

    func shouldHaveCompactHeader(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.staticTexts["Pi Pocket"].exists, file: file, line: line)
        XCTAssertFalse(app.staticTexts["Development server"].exists, file: file, line: line)
    }
    func recordAppearance(_ name: String) {
        XCTContext.runActivity(named: name) { activity in
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
    }
    func openSavedQuickChat() { app.buttons["inbox-/history/quick"].tap() }
    func moveQuickChatToLater() { app.buttons["moveLater-/history/quick"].tap() }
    func expandLater() { app.buttons["inboxToggle-later"].tap() }
    func resumeQuickChatFromLater() { app.buttons["resumeLater-/history/quick"].tap() }
    func shouldOfferQuickChatInLater(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["resumeLater-/history/quick"].waitForExistence(timeout: 5), file: file, line: line)
    }
    func expandProject(_ name: String) {}
    func openRunningSession() { app.buttons["inbox-runtime:ui-running"].tap() }
    func newProjectSession() { app.buttons["newInboxSession"].tap() }
    func back() {
        #if os(iOS)
        let leading = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(leading.waitForExistence(timeout: 4))
        leading.tap()
        #endif
    }
    func shouldShowSavedAnswer(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["message-saved-answer"].waitForExistence(timeout: 4), file: file, line: line)
    }
}
