import Testing

/// Conversation flow: admission, transcripts and stop semantics for the attached runtime.
@MainActor
struct SessionLifecycleTests {
    @Test func sendClearsDraftOnlyAfterAdmissionAndBlocksDuplicates() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.attach()
            app.chat.shouldAllowSend(true)
            try await app.chat.beginSend("Say hello")
            app.chat.clearInstructionShouldBe(nil)
            app.chat.shouldAllowSend(false)
            app.chat.submit("Duplicate")
            app.chat.stop()
            await app.server.shouldHaveStopCount(0)
            await app.server.shouldHaveSendCount(1)
            await app.server.acceptSend()
            try await app.wait("admitted send") { !app.state.isSending }
            app.chat.clearInstructionShouldBe("Say hello")
        }
    }

    @Test(arguments: [false, true])
    func sendRejectionAndUnknownOutcomeRetainDraft(unknown: Bool) async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.attach()
            try await app.chat.beginSend("Keep\n  draft\n")
            if unknown { await app.server.loseSendReceipt() } else { await app.server.rejectSend() }
            try await app.wait("settled send") { !app.state.isSending }
            app.chat.clearInstructionShouldBe(nil)
            app.session.shouldShowError(containing: unknown ? "unknown" : "Not now")
        }
    }

    @Test func projectionDrivesGeneratingAndStoppingWithoutDiscardingText() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.attach()
            try await app.server.streamReply("Partial")
            app.session.statusShouldBe("Generating…")
            app.session.shouldWarnBeforeDisconnect()
            app.chat.submit("Not while running\n")
            app.chat.stop()
            try await app.session.waitUntilStopping()
            try await app.server.waitForStops(1)
            app.chat.stop()
            app.chat.submit("Not while stopping\n")
            await app.server.shouldHaveStopCount(1)
            await app.server.shouldHaveSendCount(0)
            app.chat.shouldAllowSend(false)
            try await app.server.finishReply()
            app.session.statusShouldBe("Ready")
            app.chat.messagesShouldBe(["Partial"])
            app.session.detach()
            // The last-known conversation survives a detach.
            app.chat.messagesShouldBe(["Partial"])
            app.session.shouldBeDisconnected()
            await app.server.shouldRemainConnected()
        }
    }

    @Test func detachingDuringPendingSendRetainsDraftAndIgnoresLateFailure() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.attach()
            try await app.chat.beginSend("Keep this")
            app.session.detach()
            app.session.shouldBeDisconnected()
            app.chat.clearInstructionShouldBe(nil)
            app.chat.shouldHavePendingSend(false)
            // The send was already admitted; its late result belongs to a conversation that is
            // no longer shown and must not surface anywhere.
            await app.server.rejectSend()
            try await Task.sleep(for: .milliseconds(50))
            app.session.shouldBeDisconnected()
            await app.server.shouldRemainConnected()
        }
    }

    @Test func semanticPromptUsesMiddlewareAdmissionAndForwardsText() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.attach()
            try await app.chat.sendPrompt("Say hello")
            await app.server.receivedPromptsShouldBe(["Say hello"])
            app.chat.clearInstructionShouldBe("Say hello")
            app.chat.shouldHavePendingSend(false)
        }
    }

    @Test func snapshotPreservesWhitespaceAndIdenticalSendsClearIndependently() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.attach()
            let text = "  First\n\n    second\n"
            try await app.chat.sendPrompt(text)
            app.chat.clearInstructionShouldBe(text)
            app.chat.consumeClearInstruction()
            app.chat.clearInstructionShouldBe(nil)
            try await app.chat.beginSend(text)
            app.chat.clearInstructionShouldBe(nil)
            await app.server.acceptSend()
            try await app.wait("second admission") { !app.state.isSending }
            app.chat.clearInstructionShouldBe(text)
            await app.server.receivedPromptsShouldBe([text, text])
        }
    }

    @Test func whitespaceSnapshotsNeverReachConnection() async throws {
        try await PiIntegrationDriver.run { app in
            app.chat.submit("Detached")
            try await app.session.attach()
            for text in ["", " ", "\n\n", " \t\n"] { app.chat.submit(text) }
            await app.server.shouldHaveSendCount(0)
            app.chat.clearInstructionShouldBe(nil)
            app.chat.shouldHavePendingSend(false)
        }
    }

    @Test func queuedSendUsesOriginalSnapshotAndRejectsLaterSubmission() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.attach()
            let snapshot = "  Submit this\n\n    exactly\n"
            try await app.chat.beginSendThenSubmit(snapshot, duplicate: "Next draft")
            await app.server.receivedPromptsShouldBe([snapshot])
            await app.server.acceptSend()
            try await app.wait("admitted send") { !app.state.isSending }
            app.chat.clearInstructionShouldBe(snapshot)
        }
    }

    @Test func duplicateStopRequestsReachSDKOnlyOnce() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.attach()
            try await app.server.streamReply("Partial")
            app.chat.stopTwice()
            try await app.server.waitForStops(1)
            await app.server.shouldHaveStopCount(1)
            try await app.server.finishReply()
            app.chat.messagesShouldBe(["Partial"])
        }
    }

    @Test func releasingTheConversationStoreLeavesTheWorkspaceConnectionAlone() async throws {
        try await PiIntegrationDriver.run { app in
            try await app.session.attach()
            app.session.releaseStore()
            // The workspace owns the transport; dropping the conversation view must not close it.
            await app.server.shouldRemainConnected()
        }
    }
}
