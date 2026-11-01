import XCTest

/// Draft acceptance scenarios. Driver mechanics are deliberately not implemented yet.
final class MarkdownTranscriptScenarios: XCTestCase {
    @MainActor private var app: PiUIDriver!

    override func setUpWithError() throws { continueAfterFailure = false }

    override func setUp() async throws {
        await MainActor.run {
            app = PiUIDriver.launch(for: self)
        }
    }

    @MainActor func testUserPromptRendersMarkdownWithoutChangingSubmittedText() throws {
        app.session.connect()
        let prompt = "Explain **SwiftUI** and `@State`."

        app.chat.sendPrompt(prompt)

        try app.chat.submittedPromptShouldBe(prompt)
        try app.chat.userMessageShouldRenderMarkdown("Explain SwiftUI and @State.")
    }

    @MainActor func testAssistantMarkdownUpdatesWhileStreamingAndAfterCompletion() throws {
        app.session.connect()
        try app.chat.prepareMarkdownResponse()

        app.chat.sendPrompt("Show an example")
        try app.chat.streamResponseThrough("## Example\n\n**Par")
        try app.chat.assistantMessageShouldShowReadablePartial("Example", "Par")
        try app.chat.finishMarkdownResponse()

        try app.chat.assistantMessageShouldRenderHeadingAndCodeBlock()
    }

    @MainActor func testStoppedResponseRemainsReadableAfterDisconnect() throws {
        app.session.connect()
        try app.chat.prepareMarkdownResponse()
        app.chat.sendPrompt("Show an example")
        try app.chat.streamResponseThrough("## Example\n\nPartial text")

        app.chat.stop()
        app.session.waitUntilReady()
        app.session.disconnect()

        try app.chat.assistantMessageShouldShowReadablePartial("Example", "Partial text")
    }

    @MainActor func testRenderedMessagesRemainSelectable() throws {
        app.session.connect()
        app.chat.sendPrompt("Select **this text**")
        app.chat.waitForReply(1)
        app.session.waitUntilReady()

        try app.chat.userAndAssistantTextShouldBeSelectable()
    }
}

private enum MarkdownScenarioNotImplemented: Error {
    case driverMechanics
}

private extension UIChatDriver {
    func submittedPromptShouldBe(_ text: String) throws { throw MarkdownScenarioNotImplemented.driverMechanics }
    func userMessageShouldRenderMarkdown(_ text: String) throws { throw MarkdownScenarioNotImplemented.driverMechanics }
    func prepareMarkdownResponse() throws { throw MarkdownScenarioNotImplemented.driverMechanics }
    func streamResponseThrough(_ text: String) throws { throw MarkdownScenarioNotImplemented.driverMechanics }
    func assistantMessageShouldShowReadablePartial(_ heading: String, _ text: String) throws { throw MarkdownScenarioNotImplemented.driverMechanics }
    func finishMarkdownResponse() throws { throw MarkdownScenarioNotImplemented.driverMechanics }
    func assistantMessageShouldRenderHeadingAndCodeBlock() throws { throw MarkdownScenarioNotImplemented.driverMechanics }
    func userAndAssistantTextShouldBeSelectable() throws { throw MarkdownScenarioNotImplemented.driverMechanics }
}
