import XCTest

/// The iPhone session overview: a sheet, never a tab strip. Queries are scoped to the overview so
/// a session title in the sidebar behind it cannot be tapped by accident.
@MainActor final class UISessionOverviewDriver {
    private let app: XCUIApplication
    init(_ app: XCUIApplication) { self.app = app }

    private var overview: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "sessionOverview").firstMatch
    }

    /// The phone switches through this sheet, so it must never render a tab strip.
    func shouldNotRenderATabStrip(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "sessionTabStrip").firstMatch.exists,
                       "iPhone must not render a tab strip", file: file, line: line)
    }

    func open(file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons["sessionsButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No open-sessions button", file: file, line: line)
        button.tap()
        XCTAssertTrue(overview.waitForExistence(timeout: 4), "The overview never appeared", file: file, line: line)
    }

    func dismiss(file: StaticString = #filePath, line: UInt = #line) {
        app.buttons["closeOverview"].tap()
        XCTAssertTrue(waitForAbsence(of: overview), "The overview stayed open", file: file, line: line)
    }

    func shouldShow(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(row(title).waitForExistence(timeout: 4),
                      "No overview row for \(title). Overview:\n\(overview.debugDescription)",
                      file: file, line: line)
    }

    func shouldNotShow(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitForAbsence(of: row(title)), "\(title) is still in the overview", file: file, line: line)
    }

    func shouldBeEmpty(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["overviewEmpty"].waitForExistence(timeout: 4),
                      "The empty overview state never appeared", file: file, line: line)
    }

    /// Switching shows the conversation the row belongs to.
    func select(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        row(title).tap()
        XCTAssertTrue(app.textFields["messageField"].waitForExistence(timeout: 5),
                      "Selecting \(title) did not show its conversation", file: file, line: line)
    }

    /// Closing only ends the local view; the runtime is a server concern.
    func closeRow(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let control = overview.buttons["Close \(title) view"]
        XCTAssertTrue(control.waitForExistence(timeout: 4), "No close control for \(title)",
                      file: file, line: line)
        control.tap()
    }

    /// Status is stated, never colour-only.
    func statusShouldSay(_ title: String, _ text: String,
                         file: StaticString = #filePath, line: UInt = #line) {
        let value = row(title).value as? String ?? ""
        XCTAssertTrue(value.contains(text), "Row for \(title) reads \"\(value)\"", file: file, line: line)
    }

    func startNewSession(file: StaticString = #filePath, line: UInt = #line) {
        overview.buttons["overviewNewSession"].tap()
        XCTAssertTrue(app.textFields["messageField"].waitForExistence(timeout: 6),
                      "A new session did not open", file: file, line: line)
    }

    /// Leaves the conversation for the project list without disconnecting.
    func returnToProjects(file: StaticString = #filePath, line: UInt = #line) {
        overview.buttons["overviewProjects"].tap()
        XCTAssertTrue(app.buttons["Quick Chats"].waitForExistence(timeout: 5),
                      "The project list is not visible", file: file, line: line)
    }

    /// Every row is a full-size touch target, as the iPhone layout requires.
    func rowsShouldBeFullHeight(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let height = row(title).frame.height
        XCTAssertGreaterThanOrEqual(height, 44, "Row for \(title) is only \(height) points tall",
                                    file: file, line: line)
    }

    private func row(_ title: String) -> XCUIElement { overview.buttons[title] }

    private func waitForAbsence(of element: XCUIElement, timeout: TimeInterval = 4) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            _ = element.waitForExistence(timeout: 0.2)
        }
        return !element.exists
    }
}
