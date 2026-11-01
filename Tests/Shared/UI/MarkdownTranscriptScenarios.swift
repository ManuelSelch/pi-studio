import XCTest

final class MarkdownTranscriptScenarios: XCTestCase {
    @MainActor private var app: PiUIDriver!

    override func setUpWithError() throws { continueAfterFailure = false }

    override func setUp() async throws {
        await MainActor.run {
            app = PiUIDriver.launch(for: self, markdownResponse: true)
        }
    }

    @MainActor func testUserPromptRendersMarkdownWithoutChangingSubmittedText() throws {
        app.session.connect()
        let prompt = "Explain **SwiftUI** and `@State`."

        app.chat.sendPrompt(prompt)

        app.chat.submittedPromptShouldBe(prompt)
        app.chat.userMessageShouldRenderMarkdown("Explain SwiftUI and @State.")
    }

    @MainActor func testFormattedPromptPreservesDisplayedIndentation() throws {
        app.session.connect()
        let prompt = "  **bold** and `code`\n"

        app.chat.sendPrompt(prompt)

        app.chat.userMessageShouldBe(1, "  bold and code\n")
        app.chat.submittedPromptShouldBe(prompt)
    }

    @MainActor func testAssistantMarkdownUpdatesWhileStreamingAndAfterCompletion() throws {
        app.session.connect()
        app.chat.sendPrompt("Show an example")
        app.chat.streamResponseThrough("## Example\n\n**Par")
        app.chat.assistantMessageShouldShowReadablePartial("Example", "Par")
        app.chat.finishMarkdownResponse()

        app.chat.assistantMessageShouldRenderHeadingAndCodeBlock()
    }

    @MainActor func testStoppedResponseRemainsReadableAfterDisconnect() throws {
        app.session.connect()
        app.chat.sendPrompt("Show an example")
        app.chat.streamResponseThrough("## Example\n\nPartial text")

        app.chat.stop()
        app.session.waitUntilReady()
        app.session.disconnect()

        app.chat.assistantMessageShouldShowReadablePartial("Example", "Partial text")
    }

    @MainActor func testRenderedMessagesRemainSelectable() throws {
        app.session.connect()
        app.chat.sendPrompt("Select **this text**")
        app.chat.waitForReply(1)
        app.session.waitUntilReady()

        app.chat.userAndAssistantTextShouldBeSelectable()
    }
}

