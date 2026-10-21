import Testing

/// Workspace behaviour at the store level: consent, browsing, open identity and lifecycle.
@Suite @MainActor struct WorkspaceMiddlewareTests {
    @Test func connectListsWithoutCreatingAndQuickChatCreationIsExplicit() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            app.projects.shouldBeBrowsing()
            await app.server.shouldHaveCreates(0)
            await app.server.shouldHaveAttaches(0)
            try await app.projects.newQuickChat()
            app.projects.shouldShowSession()
            await app.server.shouldHaveCreates(1)
            await app.server.createdPathShouldBe("/home/pi")
        }
    }

    @Test func historyAndRuntimeOpenThroughDifferentIdentities() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.projects.openHistory()
            await app.server.openedHistoryShouldBe("/history/saved")
            app.projects.back()
            try await app.projects.openRunningSession()
            await app.server.attachedRuntimeShouldBe("running")
        }
    }

    @Test func failedOpenStaysInBrowserWithoutCreatingFallback() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            await app.server.rejectOpens()
            try await app.projects.openHistory()
            app.projects.shouldBeBrowsing()
            app.projects.shouldShowError(containing: "Not found")
            await app.server.shouldHaveCreates(0)
            app.tabs.shouldHaveNoTabs()
        }
    }

    @Test func aHeldOpenBlocksASecondOpenAndLeavesNoSessionBehind() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            await app.server.publishLateCatalogue()
            try await app.projects.waitForLateProject()
            await app.server.holdOpen()
            app.projects.beginOpen()
            try await app.server.waitForHeldOpen()
            #expect(app.workspace.isOpening)
            // A second open is refused while the first is admitted, and the runtime is absent.
            app.projects.beginOpen()
            await app.server.shouldHaveOpens(1)
            await app.projects.disconnect()
            try await app.server.waitForDisconnected()
            await app.server.releaseOpen()
            try await app.tabs.settle()
            app.projects.shouldNotShowSession()
            app.tabs.shouldHaveNoTabs()
        }
    }

    @Test func backDoesNotDisconnectAndDraftsDoNotLeakAcrossSessions() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.projects.newQuickChat()
            app.tabs.enterDraft("Keep here")
            app.projects.back()
            await app.server.shouldBeConnected()
            try await app.projects.openHistory()
            app.tabs.draftShouldBe("")
            try await app.projects.openRunningSession()
            app.tabs.draftShouldBe("")
            // The first tab still owns the text it was left with.
            app.tabs.draftShouldBeRetained("Keep here", for: "New chat")
        }
    }

    @Test func unknownOpenOutcomeBlocksRetryUntilExplicitReconnect() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            await app.server.loseOpenReceipt()
            try await app.projects.openHistory()
            app.projects.shouldShowError(containing: "unknown")
            try await app.projects.openHistory()
            await app.server.shouldHaveOpens(1)
        }
    }

    @Test func explicitConnectionRejectsDuplicatesAndDisconnectDisposes() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            app.projects.shouldBeDisconnected()
            try await app.projects.connect()
            app.projects.shouldBeBrowsing()
            app.projects.connectAgain()
            await app.server.shouldHaveConnectionCount(1)
            await app.projects.disconnect()
            try await app.server.waitForDisconnected()
            app.projects.shouldBeDisconnected()
            try await app.server.waitForDisposal()
            await app.server.shouldBeDisposed()
        }
    }

    @Test func connectWithoutConsentNeverReachesTheServer() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            app.projects.connectWithoutConsent()
            try await Task.sleep(for: .milliseconds(30))
            await app.server.shouldHaveConnectionCount(0)
            app.projects.shouldBeDisconnected()
        }
    }

    @Test func connectionFailureIsVisibleAndDisposed() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            await app.server.rejectConnect("Connection refused")
            try? await app.projects.connect()
            try await app.workspaceWait("connection failed") {
                if case .failed = app.workspace.connection { true } else { false }
            }
            app.projects.shouldShowError(containing: "Connection refused")
            await app.server.shouldBeDisposed()
        }
    }

    @Test func missingProjectReportsAnErrorWithoutATab() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.projects.openMissingProject()
            app.projects.shouldShowError(containing: "not available")
            app.tabs.shouldHaveNoTabs()
            await app.server.shouldHaveCreates(1)
        }
    }
}

private extension WorkspaceIntegrationDriver {
    /// Waits for workspace state that is not driver-navigated (lifecycle transitions).
    func workspaceWait(_ description: String, _ condition: @escaping () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Workspace did not settle: \(description)")
    }
}
