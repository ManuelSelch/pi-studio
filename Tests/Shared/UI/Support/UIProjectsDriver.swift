import XCTest

/// Projects gestures and rendered assertions; independent of integration mechanics.
@MainActor final class UIProjectsDriver {
    private let app: XCUIApplication
    init(_ app: XCUIApplication) { self.app = app }
    func connect(file: StaticString = #filePath, line: UInt = #line) {
        showSidebarIfNeeded(for: "connectButton")
        app.buttons["connectButton"].firstMatch.tap()
        shouldShowProject("Quick Chats", file: file, line: line)
    }
    func shouldShowHome(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["homeGreeting"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.textFields["quickSwitcher"].exists, file: file, line: line)
        XCTAssertFalse(app.staticTexts["Recent conversations"].exists, file: file, line: line)
    }
    func shouldShowHomeConnectionError(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["homeConnectionError"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.buttons["homeRetryConnection"].exists, file: file, line: line)
    }
    func retryHomeConnection(file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["homeRetryConnection"].tap()
        XCTAssertTrue(app.buttons["sessionsButton"].waitForExistence(timeout: 5),
                      "The retry did not connect", file: file, line: line)
    }
    func shouldShowProject(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 5), file: file, line: line)
    }
    func shouldBeBrowsing(file: StaticString = #filePath, line: UInt = #line) {
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
    func openSavedQuickChat() {
        showSidebarIfNeeded(for: "session-/history/quick")
        app.buttons["session-/history/quick"].tap()
    }
    func expandProject(_ name: String) {
        showSidebarIfNeeded(for: name)
        app.buttons[name].tap()
    }
    func openRunningSession() {
        showSidebarIfNeeded(for: "session-runtime:ui-running")
        app.buttons["session-runtime:ui-running"].tap()
    }
    func newProjectSession() {
        showSidebarIfNeeded(for: "newSession-/repo")
        app.buttons["newSession-/repo"].tap()
    }
    private func showSidebarIfNeeded(for identifier: String) {
        if !app.buttons[identifier].exists, app.buttons["projectsButton"].exists {
            app.buttons["projectsButton"].tap()
        }
    }
    func back() {
        #if os(iOS)
        // The workspace uses native navigation, so back is the bar's leading button.
        let leading = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(leading.waitForExistence(timeout: 4))
        leading.tap()
        #endif
    }
    func shouldShowSavedAnswer(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["message-saved-answer"].waitForExistence(timeout: 4), file: file, line: line)
    }
}
