import Testing

@MainActor
struct SessionControllerTests {
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
            app.chat.enterDraft("Say hello")
            app.chat.shouldAllowSend(true)
            try await app.chat.beginSend()
            app.chat.draftShouldBe("Say hello")
            app.chat.shouldAllowSend(false)
            await app.chat.sendAgain()
            await app.server.shouldHaveSendCount(1)
            await app.server.acceptSend()
            app.chat.draftShouldBe("")
        }
    }

    @Test(arguments: [false, true])
    func sendRejectionAndUnknownOutcomeRetainDraft(unknown: Bool) async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            app.chat.enterDraft("Keep draft")
            try await app.chat.beginSend()
            if unknown { await app.server.loseSendReceipt() }
            else { await app.server.rejectSend() }
            app.chat.draftShouldBe("Keep draft")
            app.session.shouldShowError(containing: unknown ? "unknown" : "Not now")
        }
    }

    @Test func projectionDrivesGeneratingAndStoppingWithoutDiscardingText() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.server.streamReply("Partial")
            app.session.statusShouldBe("Generating…")
            app.session.shouldWarnBeforeDisconnect()
            await app.chat.stop()
            try await app.session.waitUntilStopping()
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
            app.chat.enterDraft("Keep this")
            try await app.chat.beginSend()
            await app.session.disconnect()
            app.session.shouldBeDisconnected()
            app.chat.draftShouldBe("Keep this")
            app.session.shouldShowError(containing: "outcome unknown")
            app.chat.shouldHavePendingSend(false)
        }
    }

    @Test func releasingConnectedControllerDisposesConnection() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.session.releaseController()
            await app.server.shouldBeDisposed()
        }
    }

    @Test func semanticPromptUsesControllerAdmissionAndForwardsText() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.chat.sendPrompt("Say hello")
            await app.server.receivedPromptsShouldBe(["Say hello"])
            app.chat.draftShouldBe("")
            app.chat.shouldHavePendingSend(false)
        }
    }

    @Test func openedSessionIsAdoptedOnTheExistingConnection() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.connect()
            try await app.session.adoptOpenedSession()
            app.session.shouldBeReady()
            await app.server.shouldHaveConnectionCount(1)
            await app.server.shouldRemainConnected()
            try await app.chat.sendPrompt("Say hello")
            await app.server.receivedPromptsShouldBe(["Say hello"])
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
