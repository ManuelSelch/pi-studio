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

    @MainActor func testAssistantMarkdownUpdatesWhileStreamingAndAfterCompletion() throws {
        app.session.connect()
        app.chat.sendPrompt("Show an example")
        app.chat.streamResponseThrough("## Example\n\n**Par")
        app.chat.assistantMessageShouldShowReadablePartial("Example", "Par")
        app.chat.finishMarkdownResponse()

        app.chat.assistantMessageShouldRenderHeadingAndCodeBlock()
    }

    @MainActor func testRenderedMessagesRemainSelectable() throws {
        app.session.connect()
        app.chat.sendPrompt("Select **this text**")
        app.chat.waitForReply(1)
        app.chat.finishMarkdownResponse()

        app.chat.userAndAssistantTextShouldBeSelectable()
    }
}

