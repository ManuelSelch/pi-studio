import XCTest

final class MultilineComposerUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

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

    @MainActor func testDuplicateReturnDuringAdmissionDoesNotSubmitAgain() {
        let app = PiUIDriver.launch(for: self, delayedAdmission: true)
        app.session.connect()
        app.chat.enterDraft("Only once")
        app.chat.pressReturn()
        app.chat.pressReturn()
        app.chat.pressReturn()
        app.chat.waitForReply(1)
        app.session.waitUntilReady()
        app.chat.shouldHaveNoReply(2)
        app.chat.draftShouldBe("")
    }

    @MainActor func testRejectedMultilineSnapshotStaysEditable() {
        let app = PiUIDriver.launch(for: self, sendOutcome: .rejected)
        app.session.connect()
        let text = "Keep\n  rejected\n"
        app.chat.pasteDraft(text)
        app.chat.pressReturn()
        app.session.shouldShowError()
        app.chat.draftShouldBe(text)
        app.chat.shouldAllowSend(true)
    }

    @MainActor func testUncertainMultilineSnapshotIsNotResent() {
        let app = PiUIDriver.launch(for: self, sendOutcome: .unknown)
        app.session.connect()
        let text = "Keep\n  uncertain\n"
        app.chat.pasteDraft(text)
        app.chat.pressReturn()
        app.session.statusShouldBe("Outcome unknown")
        app.chat.pressReturn()
        app.chat.draftShouldBe(text)
        app.chat.shouldAllowSend(false)
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

    @MainActor func testNewlineOnlyDraftCannotSubmit() {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        app.chat.enterDraft("\n\n")
        app.chat.draftShouldBe("\n\n")
        app.chat.shouldAllowSend(false)
        app.chat.shouldHaveNoReply()
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

    @MainActor func testRejectedMultilineDraftIsRetained() {
        let app = PiUIDriver.launch(for: self, sendOutcome: .rejected)
        app.session.connect()
        app.chat.sendPrompt("Keep\n  rejected\n")
        app.session.shouldShowError()
        app.chat.draftShouldBe("Keep\n  rejected\n")
    }

    @MainActor func testUncertainMultilineDraftIsRetained() {
        let app = PiUIDriver.launch(for: self, sendOutcome: .unknown)
        app.session.connect()
        app.chat.sendPrompt("Keep\n  uncertain\n")
        app.session.statusShouldBe("Outcome unknown")
        app.chat.draftShouldBe("Keep\n  uncertain\n")
    }
    #endif
}
