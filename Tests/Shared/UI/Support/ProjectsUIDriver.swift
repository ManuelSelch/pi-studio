import XCTest

/// Session inbox gestures and rendered assertions; independent of integration mechanics.
@MainActor final class ProjectsUIDriver {
    private let app: XCUIApplication
    init(_ app: XCUIApplication) { self.app = app }

    func connect(file: StaticString = #filePath, line: UInt = #line) {
        showSidebarIfNeeded(for: "connectButton")
        app.buttons["connectButton"].firstMatch.tap()
        XCTAssertTrue(app.buttons["newInboxSession"].waitForExistence(timeout: 5), file: file, line: line)
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

    func shouldHaveInboxGroup(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5), file: file, line: line)
    }

    func shouldNotShowProjectHistory(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.staticTexts["Projects & history"].exists, file: file, line: line)
    }

    func shouldBeBrowsing(file: StaticString = #filePath, line: UInt = #line) {
        let home = app.staticTexts["homeGreeting"]
        let inbox = app.buttons["newInboxSession"]
        XCTAssertTrue(home.waitForExistence(timeout: 2) || inbox.waitForExistence(timeout: 5),
                      "Neither Home nor the session inbox is visible", file: file, line: line)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "messageField").firstMatch.exists,
                       file: file, line: line)
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

    func openSavedQuickChat() {
        showSidebarIfNeeded(for: "inbox-/history/quick")
        app.buttons["inbox-/history/quick"].tap()
    }

    func moveQuickChatToLater() {
        showSidebarIfNeeded(for: "moveLater-/history/quick")
        app.buttons["moveLater-/history/quick"].tap()
    }

    func expandLater() {
        showSidebarIfNeeded(for: "inboxToggle-later")
        app.buttons["inboxToggle-later"].tap()
    }

    func resumeQuickChatFromLater() {
        showSidebarIfNeeded(for: "resumeLater-/history/quick")
        app.buttons["resumeLater-/history/quick"].tap()
    }

    func shouldOfferQuickChatInLater(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.buttons["resumeLater-/history/quick"].waitForExistence(timeout: 5), file: file, line: line)
    }

    func expandProject(_ name: String) {}

    func openRunningSession() {
        showSidebarIfNeeded(for: "inbox-runtime:ui-running")
        app.buttons["inbox-runtime:ui-running"].tap()
    }

    func newProjectSession() {
        showSidebarIfNeeded(for: "newInboxSession")
        app.buttons["newInboxSession"].tap()
    }

    func back() {
        #if os(iOS)
        let leading = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(leading.waitForExistence(timeout: 4))
        leading.tap()
        #endif
    }

    func shouldShowSavedAnswer(file: StaticString = #filePath, line: UInt = #line) {
        let answer = app.descendants(matching: .any).matching(identifier: "message-saved-answer").firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: 4), file: file, line: line)
    }

    private func showSidebarIfNeeded(for identifier: String) {
        if !app.buttons[identifier].exists, app.buttons["projectsButton"].exists {
            app.buttons["projectsButton"].tap()
        }
    }
}
