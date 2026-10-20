import XCTest

/// Projects gestures and rendered assertions; independent of integration mechanics.
@MainActor final class UIProjectsDriver {
    private let app: XCUIApplication
    init(_ app: XCUIApplication) { self.app = app }
    func connect(file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["connectButton"].tap()
        let consent = confirmation.buttons["Connect and take control"]
        XCTAssertTrue(consent.waitForExistence(timeout: 4), file: file, line: line)
        consent.tap()
        shouldShowProject("Quick Chats", file: file, line: line)
    }
    private var confirmation: XCUIElement {
        #if os(macOS)
        app.sheets.firstMatch
        #else
        app.alerts.firstMatch
        #endif
    }
    func shouldShowProject(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 5), file: file, line: line)
    }
    func shouldBeBrowsing(file: StaticString = #filePath, line: UInt = #line) {
        shouldShowProject("Quick Chats", file: file, line: line)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "messageField").firstMatch.exists, file: file, line: line)
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
    func openSavedQuickChat() { app.buttons["session-/history/quick"].tap() }
    func expandProject(_ name: String) { app.buttons[name].tap() }
    func openRunningSession() { app.buttons["session-runtime:ui-running"].tap() }
    func newProjectSession() { app.buttons["newSession-/repo"].tap() }
    func back() { app.buttons["projectsBack"].tap() }
    func shouldShowSavedAnswer(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["message-saved-answer"].waitForExistence(timeout: 4), file: file, line: line)
    }
}
