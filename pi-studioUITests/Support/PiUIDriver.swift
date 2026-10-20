import XCTest

/// UI implementation of the semantic DSL. Never reads controller/store state.
@MainActor
final class PiUIDriver {
    enum SendOutcome { case accepted, rejected, unknown }
    let session: UISessionDriver
    let chat: UIChatDriver
    let projects: UIProjectsDriver

    private init(_ context: UIContext) {
        session = UISessionDriver(context)
        chat = UIChatDriver(context)
        projects = UIProjectsDriver(context.app)
    }

    static func launch(for test: XCTestCase, sendOutcome: SendOutcome = .accepted, rejectOpen: Bool = false) -> PiUIDriver {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if rejectOpen { app.launchArguments.append("--ui-open-rejected") }
        switch sendOutcome {
        case .accepted: break
        case .rejected: app.launchArguments.append("--ui-send-rejected")
        case .unknown: app.launchArguments.append("--ui-send-unknown")
        }
        #if os(iOS)
        // Appearance tests rotate the simulator; functional scenarios own orientation.
        XCUIDevice.shared.orientation = .portrait
        #endif
        app.launch()
        test.addTeardownBlock { @MainActor in app.terminate() }
        return PiUIDriver(UIContext(app))
    }
}

@MainActor
fileprivate final class UIContext {
    let app: XCUIApplication
    init(_ app: XCUIApplication) { self.app = app }

    var messageField: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "messageField").firstMatch
    }
    var alert: XCUIElement {
        #if os(macOS)
        app.sheets.firstMatch
        #else
        app.alerts.firstMatch
        #endif
    }
    func renderedText(_ element: XCUIElement) -> String {
        #if os(macOS)
        element.value as? String ?? element.label
        #else
        element.label
        #endif
    }
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 4,
                 file: StaticString, line: UInt) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Expected \(element)", file: file, line: line)
    }
}

@MainActor
final class UISessionDriver {
    private let context: UIContext
    fileprivate init(_ context: UIContext) { self.context = context }

    func requestConnect() { context.app.buttons["connectButton"].tap() }
    func cancelConnect(file: StaticString = #filePath, line: UInt = #line) {
        let cancel = context.alert.buttons["Cancel"]
        context.waitFor(cancel, file: file, line: line)
        cancel.tap()
    }
    func connect(file: StaticString = #filePath, line: UInt = #line) {
        connectToServer(file: file, line: line)
        let newChat = context.app.buttons["newSession-/home/pi"]
        context.waitFor(newChat, file: file, line: line)
        newChat.tap()
        waitUntilReady(file: file, line: line)
    }
    fileprivate func connectToServer(file: StaticString, line: UInt) {
        requestConnect()
        let consent = context.alert.buttons["Connect and take control"]
        context.waitFor(consent, file: file, line: line)
        consent.tap()
        context.waitFor(context.app.staticTexts["Connected"], timeout: 5, file: file, line: line)
    }
    func requestDisconnect() { context.app.buttons["connectButton"].tap() }
    func disconnect() {
        requestDisconnect()
        let confirm = context.alert.buttons["Disconnect"]
        if confirm.waitForExistence(timeout: 1) { confirm.tap() }
    }
    func shouldShowDisconnectWarning(file: StaticString = #filePath, line: UInt = #line) {
        context.waitFor(context.alert, file: file, line: line)
        context.waitFor(context.alert.buttons["Disconnect"], file: file, line: line)
    }
    func confirmDisconnect() { context.alert.buttons["Disconnect"].tap() }
    func shouldBeDisconnected(file: StaticString = #filePath, line: UInt = #line) {
        statusShouldBe("Disconnected", file: file, line: line)
    }
    func statusShouldBe(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        context.waitFor(context.app.staticTexts[text], file: file, line: line)
    }
    func waitUntilReady(file: StaticString = #filePath, line: UInt = #line) {
        context.waitFor(context.app.staticTexts["Ready"], timeout: 5, file: file, line: line)
    }
    func waitUntilStopping(file: StaticString = #filePath, line: UInt = #line) {
        statusShouldBe("Stopping…", file: file, line: line)
    }
    func shouldShowError(file: StaticString = #filePath, line: UInt = #line) {
        context.waitFor(context.app.staticTexts["errorMessage"], file: file, line: line)
    }
}

@MainActor
final class UIChatDriver {
    private let context: UIContext
    fileprivate init(_ context: UIContext) { self.context = context }
    private func reply(_ number: Int) -> XCUIElement { context.app.staticTexts["message-assistant-\(number)"] }

    func sendPrompt(_ text: String) {
        let field = context.messageField
        field.tap(); field.typeText(text)
        context.app.buttons["sendButton"].tap()
    }
    func stop() { context.app.buttons["stopButton"].tap() }
    func shouldAllowSend(_ allowed: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let button = context.app.buttons["sendButton"]
        XCTAssertEqual(button.exists && button.isEnabled, allowed, file: file, line: line)
    }
    func shouldAllowStop(_ allowed: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let button = context.app.buttons["stopButton"]
        XCTAssertEqual(button.exists && button.isEnabled, allowed, file: file, line: line)
    }
    func waitForReply(_ number: Int, file: StaticString = #filePath, line: UInt = #line) {
        context.waitFor(reply(number), file: file, line: line)
    }
    func shouldContainReply(_ number: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(reply(number).exists, file: file, line: line)
    }
    func captureReply(_ number: Int, file: StaticString = #filePath, line: UInt = #line) -> String {
        waitForReply(number, file: file, line: line)
        let text = context.renderedText(reply(number))
        XCTAssertFalse(text.isEmpty, file: file, line: line)
        return text
    }
    func replyShouldBe(_ number: Int, _ text: String, file: StaticString = #filePath, line: UInt = #line) {
        shouldContainReply(number, file: file, line: line)
        XCTAssertEqual(context.renderedText(reply(number)), text, file: file, line: line)
    }
    func draftShouldBe(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(context.messageField.value as? String, text, file: file, line: line)
    }
}
