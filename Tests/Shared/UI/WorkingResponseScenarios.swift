import XCTest

final class WorkingResponseScenarios: XCTestCase {
    @MainActor func testWorkingRemainsVisibleAcrossResponseFragmentsUntilCompletion() throws {
        let conversation = WorkingResponseDriver(test: self)
        try conversation.startResponse()
        try conversation.workingShouldBeVisible(true)

        try conversation.showAssistantFragment("I’ll inspect the implementation.")
        try conversation.simulateToolActivity()
        try conversation.workingShouldBeVisible(true)
        try conversation.showAssistantFragment("I’ve updated the tests.")
        try conversation.workingShouldBeVisible(true)

        try conversation.finishResponse()
        try conversation.workingShouldBeVisible(false)
        try conversation.assistantFragmentsShouldBeVisible(["I’ll inspect the implementation.", "I’ve updated the tests."])
    }

}

/// Exercises the real UI against a timed, debug-only multi-fragment projection fixture.
@MainActor
private final class WorkingResponseDriver {
    private let app: PiUIDriver
    private let defaultPrompt: String
    private var turn = 0
    private var part = 0
    private var sent = false

    init(test: XCTestCase, defaultPrompt: String = "Check implementation") {
        app = PiUIDriver.launch(for: test, workingResponse: true)
        self.defaultPrompt = defaultPrompt
        app.session.connect()
    }
    func startResponse() throws {
        if !sent { try showUserMessage(defaultPrompt) }
        app.chat.workingShouldBeVisible(true)
    }
    func showUserMessage(_ text: String) throws {
        app.chat.sendPrompt(text)
        turn += 1
        part = 0
        sent = true
    }
    func showAssistantFragment(_ text: String) throws {
        part += 1
        app.chat.fragmentShouldBeVisible(turn: turn, part: part, text: text)
    }
    func simulateToolActivity() throws { app.chat.toolActivityShouldBeInProgress(turn: turn) }
    func finishResponse() throws {
        app.chat.workingShouldBeVisible(false)
        app.session.waitUntilReady()
        sent = false
    }
    func workingShouldBeVisible(_ visible: Bool) throws { app.chat.workingShouldBeVisible(visible) }
    func assistantFragmentsShouldBeVisible(_ fragments: [String]) throws {
        for (index, text) in fragments.enumerated() {
            app.chat.fragmentShouldBeVisible(turn: turn, part: index + 1, text: text)
        }
    }
}
