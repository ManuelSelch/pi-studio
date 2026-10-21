import Testing

@MainActor
struct SessionLifecycleTests {
    @Test func explicitConnectionDisablesDuplicateCreateAndDisconnectDisposes() async throws {
        try await PiIntegrationDriver.run { app in
            app.session.shouldBeDisconnected()
            try await app.session.beginConnect()
            app.session.shouldBeConnecting()
            await app.session.connectAgain()
            await app.server.shouldHaveConnectionCount(1)
            try await app.server.acceptConnection()
            app.session.shouldBeReady()
            await app.session.disconnect()
            app.session.shouldBeDisconnected()
            await app.server.shouldBeDisposed()
        }
    }

    @Test func disconnectWhileConnectingIgnoresObsoleteFailure() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.beginConnect()
            await app.session.disconnect()
            app.session.shouldBeDisconnected()
            await app.server.shouldBeDisposed()
        }
    }

    @Test func sendClearsDraftOnlyAfterAdmissionAndBlocksDuplicates() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            app.chat.shouldAllowSend(true)
            try await app.chat.beginSend("Say hello")
            app.chat.clearInstructionShouldBe(nil)
            app.chat.shouldAllowSend(false)
            await app.chat.submit("Duplicate")
            await app.chat.stop()
            await app.server.shouldHaveStopCount(0)
            await app.server.shouldHaveSendCount(1)
            await app.server.acceptSend()
            app.chat.clearInstructionShouldBe("Say hello")
        }
    }

    @Test(arguments: [false, true])
    func sendRejectionAndUnknownOutcomeRetainDraft(unknown: Bool) async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.chat.beginSend("Keep\n  draft\n")
            if unknown { await app.server.loseSendReceipt() }
            else { await app.server.rejectSend() }
            app.chat.clearInstructionShouldBe(nil)
            app.session.shouldShowError(containing: unknown ? "unknown" : "Not now")
        }
    }

    @Test func projectionDrivesGeneratingAndStoppingWithoutDiscardingText() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.server.streamReply("Partial")
            app.session.statusShouldBe("Generating…")
            app.session.shouldWarnBeforeDisconnect()
            await app.chat.submit("Not while running\n")
            await app.chat.stop()
            try await app.session.waitUntilStopping()
            await app.chat.stop()
            await app.chat.submit("Not while stopping\n")
            await app.server.shouldHaveStopCount(1)
            await app.server.shouldHaveSendCount(0)
            app.chat.shouldAllowSend(false)
            try await app.server.finishReply()
            app.session.statusShouldBe("Ready")
            await app.session.disconnect()
            app.chat.messagesShouldBe(["Partial"])
        }
    }

    @Test func connectionFailureIsVisibleAndDisposed() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.beginConnect()
            await app.server.rejectConnection("Connection refused")
            app.session.statusShouldBe("Connection failed")
            app.session.shouldShowError(containing: "Connection refused")
            await app.server.shouldBeDisposed()
        }
    }

    @Test func disconnectDuringPendingSendRetainsDraftAndIgnoresLateFailure() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.chat.beginSend("Keep this")
            await app.session.disconnect()
            app.session.shouldBeDisconnected()
            app.chat.clearInstructionShouldBe(nil)
            app.session.shouldShowError(containing: "outcome unknown")
            app.chat.shouldHavePendingSend(false)
        }
    }

    @Test func releasingConnectedStoreDisposesConnection() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.session.releaseStore()
            await app.server.shouldBeDisposed()
        }
    }

    @Test func semanticPromptUsesMiddlewareAdmissionAndForwardsText() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.chat.sendPrompt("Say hello")
            await app.server.receivedPromptsShouldBe(["Say hello"])
            app.chat.clearInstructionShouldBe("Say hello")
            app.chat.shouldHavePendingSend(false)
        }
    }

    @Test func snapshotPreservesWhitespaceAndIdenticalSendsClearIndependently() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            let text = "  First\n\n    second\n"
            try await app.chat.sendPrompt(text)
            app.chat.clearInstructionShouldBe(text)
            app.chat.consumeClearInstruction()
            app.chat.clearInstructionShouldBe(nil)
            try await app.chat.beginSend(text)
            app.chat.clearInstructionShouldBe(nil)
            await app.server.acceptSend()
            app.chat.clearInstructionShouldBe(text)
            await app.server.receivedPromptsShouldBe([text, text])
        }
    }

    @Test func whitespaceSnapshotsNeverReachConnection() async throws {
        try await PiIntegrationDriver.run { app in
            await app.chat.submit("Disconnected")
            try await app.session.connect()
            for text in ["", " ", "\n\n", " \t\n"] { await app.chat.submit(text) }
            await app.server.shouldHaveSendCount(0)
            app.chat.clearInstructionShouldBe(nil)
            app.chat.shouldHavePendingSend(false)
        }
    }

    @Test func releasingStoreDuringSetupDisposesConnection() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.beginConnect()
            try await app.session.releaseStore()
            await app.server.shouldBeDisposed()
        }
    }

    @Test func releasingStoreDuringPendingSendDisposesConnection() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.chat.beginSend("Uncertain")
            try await app.session.releaseStore()
            await app.server.shouldBeDisposed()
        }
    }

    @Test func queuedSendUsesOriginalSnapshotAndRejectsLaterSubmission() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            let snapshot = "  Submit this\n\n    exactly\n"
            try await app.chat.beginSendThenSubmit(snapshot, duplicate: "Next draft")
            await app.server.receivedPromptsShouldBe([snapshot])
            await app.server.acceptSend()
            app.chat.clearInstructionShouldBe(snapshot)
        }
    }

    @Test func duplicateStopRequestsReachSDKOnlyOnce() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.server.streamReply("Partial")
            await app.chat.stopTwice()
            await app.server.shouldHaveStopCount(1)
            app.chat.messagesShouldBe(["Partial"])
        }
    }

    @Test func noConnectionWithoutExplicitConsent() async throws {
        try await PiIntegrationDriver.run { app in
            await app.session.connectWithoutConsent()
            await app.server.shouldHaveConnectionCount(0)
            app.session.shouldBeDisconnected()
        }
    }
}
