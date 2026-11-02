import XCTest

final class MultilineComposerUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testComposerHasInlineActionWithoutDivider() throws {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()

        try app.chat.composerShouldHaveInlineActionWithoutDivider()
        app.chat.enterDraft("Hello")
        app.chat.submitDraft()
        app.chat.waitForReply(1)
        app.chat.userMessageShouldBe(1, "Hello")
    }

    #if os(macOS)
    @MainActor func testReturnSubmitsAndFocusReturnsAfterRun() {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        app.chat.enterDraft("First")
        app.chat.pressReturn()
        app.chat.waitForReply(1)
        app.chat.userMessageShouldBe(1, "First")
        app.session.waitUntilReady()
        app.chat.draftShouldBe("")
        app.chat.typeAtCaret("Second")
        app.chat.draftShouldBe("Second")
        app.chat.pressReturn()
        app.chat.waitForReply(2)
    }

    @MainActor func testShiftReturnInsertsAtCaretAndReplacesSelectionWithUndo() {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        app.chat.enterDraft("ab")
        app.chat.moveCaretToStart()
        app.chat.pressShiftReturn()
        app.chat.draftShouldBe("\nab")
        app.chat.undo()
        app.chat.draftShouldBe("ab")
        app.chat.selectAll()
        app.chat.pressShiftReturn()
        app.chat.draftShouldBe("\n")
        app.chat.shouldAllowSend(false)
        app.chat.pressReturn()
        app.chat.draftShouldBe("\n")
        app.chat.shouldHaveNoReply()
    }

    @MainActor func testPastedMultilineDoesNotSendUntilReturnAndEscapeStops() {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        let text = "  First\n\n    second\n"
        app.chat.pasteDraft(text)
        app.chat.draftShouldBe(text)
        app.chat.shouldHaveNoReply()
        app.chat.pressReturn()
        app.chat.waitForReply(1)
        app.chat.userMessageShouldBe(1, text)
        app.chat.shouldAllowStop(false) // No separate macOS Stop button.
        app.chat.stop()
        app.session.waitUntilStopping()
        app.chat.stop() // Repeated cancellation must not restart the stop effect.
        app.session.waitUntilReady()
        app.chat.shouldContainReply(1)
    }

    #else
    @MainActor func testReturnAndShiftReturnInsertNewlinesAndOnlyIconSubmits() {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        app.chat.enterDraft("First")
        app.chat.pressReturn()
        app.chat.enterDraft("  second")
        app.chat.pressShiftReturn()
        app.chat.draftShouldBe("First\n  second\n")
        app.chat.shouldHaveNoReply()
        app.chat.sendIconShouldBeAccessible()
        app.chat.submitDraft()
        app.chat.waitForReply(1)
        app.chat.userMessageShouldBe(1, "First\n  second\n")
        app.chat.shouldAllowStop(true)
        app.chat.stop()
        app.session.waitUntilStopping()
        app.chat.shouldAllowStop(false)
        app.session.waitUntilReady()
        app.chat.draftShouldBe("")
    }

    @MainActor func testSoftwareReturnInsertsNewlineWithoutSending() {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        app.chat.enterDraft("Software")
        app.chat.pressSoftwareReturn()
        app.chat.draftShouldBe("Software\n")
        app.chat.shouldHaveNoReply()
        app.chat.submitDraft()
        app.chat.waitForReply(1)
        app.chat.userMessageShouldBe(1, "Software\n")
    }

    @MainActor func testLongMultilineDraftScrollsAndPreservesPayload() {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        let text = (1...8).map { "  Line \($0) with wrapping text" }.joined(separator: "\n")
        app.chat.enterDraft(text)
        app.chat.draftShouldBe(text)
        app.chat.submitDraft()
        app.chat.waitForReply(1)
        app.chat.userMessageShouldBe(1, text)
    }

    #endif
}
