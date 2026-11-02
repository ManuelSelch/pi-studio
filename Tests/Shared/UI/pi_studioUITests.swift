import XCTest

final class pi_studioUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testConnectionCanBeStartedWithoutTakeoverConfirmation() throws {
        let app = PiUIDriver.launch(for: self)
        app.projects.connect()
        app.projects.shouldBeBrowsing()
    }

    @MainActor func testTwoTurnsStreamingStopAndDisconnectRetention() throws {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        app.chat.sendPrompt("Say hello")
        app.chat.waitForReply(1)
        app.session.statusShouldBe("Generating…")
        app.chat.shouldAllowSend(false)
        app.session.waitUntilReady()
        app.chat.replyShouldBe(1, "Hello from the demo. This reply is streaming a little at a time.")
        app.chat.sendPrompt("Second turn")
        app.chat.waitForReply(2)
        app.chat.stop()
        app.session.waitUntilStopping()
        app.session.waitUntilReady()
        let partial = app.chat.captureReply(2)
        app.session.disconnect()
        app.session.shouldBeDisconnected()
        app.chat.replyShouldBe(2, partial)
    }

    @MainActor func testActiveDisconnectWarnsWithoutDiscardingTranscript() throws {
        let app = PiUIDriver.launch(for: self)
        app.session.connect()
        app.chat.sendPrompt("Long answer")
        app.chat.waitForReply(1)
        app.session.requestDisconnect()
        app.session.shouldShowDisconnectWarning()
        app.session.confirmDisconnect()
        app.session.shouldBeDisconnected()
        app.chat.shouldContainReply(1)
    }

    @MainActor func testRejectedSendRetainsDraftAndShowsError() throws {
        let app = PiUIDriver.launch(for: self, sendOutcome: .rejected)
        app.session.connect()
        app.chat.sendPrompt("Keep draft")
        app.session.shouldShowError()
        app.chat.draftShouldBe("Keep draft")
        app.session.statusShouldBe("Ready")
    }
}
