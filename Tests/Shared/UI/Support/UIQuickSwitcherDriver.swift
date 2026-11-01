import XCTest

/// UI-only quick-switcher actions and assertions; fixture identities stay here.
@MainActor
final class UIQuickSwitcherDriver {
    private let app: XCUIApplication
    init(_ app: XCUIApplication) { self.app = app }

    private var searchField: XCUIElement { app.textFields["quickSwitcherSearch"] }
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    func homeShouldShowHeading(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let heading = app.staticTexts["homeGreeting"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(heading.label, text, file: file, line: line)
    }
    func openFromHomeSearch(file: StaticString = #filePath, line: UInt = #line) throws {
        let field = app.textFields["quickSwitcher"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), file: file, line: line)
        field.tap()
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), file: file, line: line)
    }
    func shouldBeInline(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.staticTexts["homeGreeting"].exists, file: file, line: line)
    }
    func shouldBeDialog(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(app.staticTexts["sessionTitle"].exists, file: file, line: line)
    }
    func shouldShowRecentSessions(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(app.buttons["quickSwitcherResult-history:/history/quick"].waitForExistence(timeout: 5), file: file, line: line)
    }
    func dismiss(file: StaticString = #filePath, line: UInt = #line) throws {
        let button = app.buttons["quickSwitcherDismiss"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        button.tap()
        XCTAssertFalse(searchField.waitForExistence(timeout: 1), file: file, line: line)
    }
    func homeSearchShouldBeCollapsed(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(app.textFields["quickSwitcher"].waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertFalse(searchField.exists, file: file, line: line)
    }
    #if os(macOS)
    func openUsingShortcut(_ key: String) throws {
        app.typeKey(key, modifierFlags: .command)
    }
    func focusComposer(file: StaticString = #filePath, line: UInt = #line) throws {
        let composer = element("messageField")
        XCTAssertTrue(composer.waitForExistence(timeout: 5), file: file, line: line)
        composer.tap()
    }
    func composerShouldRegainFocus(file: StaticString = #filePath, line: UInt = #line) throws {
        let composer = element("messageField")
        XCTAssertTrue(composer.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(composer.value(forKey: "hasKeyboardFocus") as? Bool, true, file: file, line: line)
    }
    #endif
    func filter(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let button = app.buttons["quickSwitcherFilter-\(name)"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        button.tap()
    }
    func search(_ text: String, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), file: file, line: line)
        searchField.tap()
        searchField.typeText(text)
    }
    func shouldShowResult(_ title: String, kind: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let id: String
        switch kind {
        case "Folders": id = "project:/home/pi"
        case "Worktrees": id = "project:/worktree/pocket"
        default: id = "history:/history/quick"
        }
        let result = app.buttons["quickSwitcherResult-\(id)"]
        XCTAssertTrue(result.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertTrue(result.label.contains(title), file: file, line: line)
    }
    func shouldShowNoActions(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(element("quickSwitcherEmpty").waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "quickSwitcherResult-")).count, 0, file: file, line: line)
    }
    func selectFolder(_ name: String) throws {
        try filter("Folders")
        try shouldShowResult(name, kind: "Folders")
        try select("project:/home/pi")
    }
    func selectWorktree(_ name: String) throws {
        try filter("Worktrees")
        try shouldShowResult(name, kind: "Worktrees")
        try select("project:/worktree/pocket")
    }
    func selectSession(_ title: String) throws {
        try filter("Sessions")
        try shouldShowResult(title, kind: "Sessions")
        try select("history:/history/quick")
    }
    private func select(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let button = app.buttons["quickSwitcherResult-\(id)"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        button.tap()
    }
    func shouldShowNewSession(in context: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let title = app.staticTexts["sessionTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(title.label, context == "Quick Chats" ? "New chat" : "New session", file: file, line: line)
        XCTAssertEqual(app.staticTexts["sessionContext"].label, context == "Quick Chats" ? "/home/pi" : "/worktree/pocket", file: file, line: line)
    }
    func openFromSession(file: StaticString = #filePath, line: UInt = #line) throws {
        #if os(macOS)
        try openUsingShortcut("k")
        #else
        let button = app.buttons["openQuickSwitcher"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), file: file, line: line)
        button.tap()
        #endif
    }
    func shouldShowSession(_ title: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let label = app.staticTexts["sessionTitle"]
        XCTAssertTrue(label.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(label.label, title, file: file, line: line)
    }
    #if os(iOS)
    func shouldShowOneOpenSession(_ title: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let overview = app.buttons["sessionsButton"]
        XCTAssertTrue(overview.waitForExistence(timeout: 5), file: file, line: line)
        overview.tap()
        let sessions = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "overviewSession-"))
        XCTAssertEqual(sessions.count, 1, file: file, line: line)
        XCTAssertTrue(sessions.firstMatch.label.contains(title), file: file, line: line)
    }
    #endif
}
