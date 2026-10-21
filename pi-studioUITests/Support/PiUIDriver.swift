import XCTest
#if os(macOS)
import AppKit
#endif

/// UI implementation of the semantic DSL. Never reads controller/store state.
@MainActor
final class PiUIDriver {
    enum SendOutcome { case accepted, rejected, unknown }
    let session: UISessionDriver
    let chat: UIChatDriver
    let settings: UISettingsDriver
    private let context: UIContext

    private init(_ context: UIContext) {
        self.context = context
        session = UISessionDriver(context)
        chat = UIChatDriver(context)
        settings = UISettingsDriver(context)
    }

    static func launch(for test: XCTestCase, sendOutcome: SendOutcome = .accepted, delayedAdmission: Bool = false) -> PiUIDriver {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-settings-suite", "PiStudio.UITests." + UUID().uuidString, "--ui-reset-settings"]
        switch sendOutcome {
        case .accepted: break
        case .rejected: app.launchArguments.append("--ui-send-rejected")
        case .unknown: app.launchArguments.append("--ui-send-unknown")
        }
        if delayedAdmission { app.launchArguments.append("--ui-send-delayed") }
        #if os(iOS)
        // Appearance tests rotate the simulator; functional scenarios own orientation.
        XCUIDevice.shared.orientation = .portrait
        #endif
        app.launch()
        test.addTeardownBlock { @MainActor in
            app.terminate()
            app.launchArguments.append("--ui-reset-settings")
            app.launch()
            app.terminate()
        }
        return PiUIDriver(UIContext(app))
    }

    func relaunch() {
        context.app.terminate()
        context.app.launchArguments.removeAll { $0 == "--ui-reset-settings" }
        context.app.launch()
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
        requestConnect()
        let consent = context.alert.buttons["Connect and take control"]
        context.waitFor(consent, file: file, line: line)
        consent.tap()
        waitUntilReady(file: file, line: line)
    }
    func requestDisconnect() { context.app.buttons["connectButton"].tap() }
    func disconnect() { requestDisconnect() }
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
final class UISettingsDriver {
    private let context: UIContext
    fileprivate init(_ context: UIContext) { self.context = context }
    private var field: XCUIElement { context.app.textFields["endpointField"].firstMatch }

    func open(file: StaticString = #filePath, line: UInt = #line) {
        context.app.buttons["settingsButton"].firstMatch.tap()
        context.waitFor(field, file: file, line: line)
    }
    func enterEndpoint(_ text: String) {
        field.tap()
        #if os(macOS)
        field.typeKey("a", modifierFlags: .command)
        field.typeText(text)
        #else
        let value = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        field.typeText(text)
        #endif
    }
    func save() { context.app.buttons["saveSettingsButton"].firstMatch.tap() }
    func cancel() { context.app.buttons["cancelSettingsButton"].firstMatch.tap() }
    func endpointShouldBe(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(field.value as? String, text, file: file, line: line)
    }
    func shouldShowValidationError(file: StaticString = #filePath, line: UInt = #line) {
        context.waitFor(context.app.staticTexts["settingsError"].firstMatch, file: file, line: line)
    }
    func shouldBeClosed(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(field.waitForNonExistence(timeout: 4), file: file, line: line)
    }
    func sessionDetailsShouldContain(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let details = context.app.staticTexts["connectionDetails"].firstMatch
        context.waitFor(details, file: file, line: line)
        XCTAssertTrue(context.renderedText(details).contains(text), file: file, line: line)
    }
}

@MainActor
final class UIChatDriver {
    private let context: UIContext
    fileprivate init(_ context: UIContext) { self.context = context }
    private func reply(_ number: Int) -> XCUIElement { context.app.staticTexts["message-assistant-\(number)"] }

    func enterDraft(_ text: String) {
        let field = context.messageField
        field.tap(); field.typeText(text)
    }
    func submitDraft() { context.app.buttons["sendButton"].tap() }
    func sendPrompt(_ text: String) {
        enterDraft(text)
        submitDraft()
    }
    func stop() {
        #if os(macOS)
        context.app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        #else
        context.app.buttons["stopButton"].tap()
        #endif
    }
    func shouldAllowSend(_ allowed: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let button = context.app.buttons["sendButton"]
        XCTAssertEqual(button.exists && button.isEnabled, allowed, file: file, line: line)
    }
    func shouldAllowStop(_ allowed: Bool, file: StaticString = #filePath, line: UInt = #line) {
        #if os(macOS)
        XCTAssertFalse(context.app.buttons["stopButton"].exists, file: file, line: line)
        #else
        let button = context.app.buttons["stopButton"]
        XCTAssertEqual(button.exists && button.isEnabled, allowed, file: file, line: line)
        #endif
    }
    func pressReturn() {
        #if os(macOS)
        context.app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: [])
        #else
        context.messageField.typeText("\n")
        #endif
    }
    func pressShiftReturn() {
        #if os(macOS)
        context.app.typeKey(XCUIKeyboardKey.return.rawValue, modifierFlags: .shift)
        #else
        // XCTest typeText covers newline insertion; physical Shift+Return is a manual check.
        context.messageField.typeText("\n")
        #endif
    }
    func pressSoftwareReturn(file: StaticString = #filePath, line: UInt = #line) {
        #if os(iOS)
        let key = context.app.keyboards.buttons["Return"].firstMatch
        context.waitFor(key, file: file, line: line)
        key.tap()
        #endif
    }
    func sendIconShouldBeAccessible(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(context.app.buttons["sendButton"].label, "Send", file: file, line: line)
    }
    func userMessageShouldBe(_ number: Int, _ text: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        let message = context.app.staticTexts["message-user-\(number)"]
        context.waitFor(message, file: file, line: line)
        XCTAssertEqual(context.renderedText(message), text, file: file, line: line)
    }
    func shouldHaveNoReply(_ number: Int = 1, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(reply(number).exists, file: file, line: line)
    }
    #if os(macOS)
    func typeAtCaret(_ text: String) { context.app.typeText(text) }
    func moveCaretToStart() { context.messageField.typeKey(XCUIKeyboardKey.leftArrow.rawValue, modifierFlags: .command) }
    func selectAll() { context.messageField.typeKey("a", modifierFlags: .command) }
    func undo() { context.messageField.typeKey("z", modifierFlags: .command) }
    func pasteDraft(_ text: String) {
        let original: [NSPasteboardItem] = NSPasteboard.general.pasteboardItems?.map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        } ?? []
        defer {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(original)
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        context.messageField.tap()
        context.messageField.typeKey("v", modifierFlags: .command)
    }
    #endif
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
