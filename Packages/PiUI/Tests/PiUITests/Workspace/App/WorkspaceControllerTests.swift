import Testing

@Suite @MainActor struct ProjectsControllerTests {
    @Test func connectListsWithoutCreatingAndQuickChatCreationIsExplicit() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            await app.projects.connect()
            app.projects.shouldBeBrowsing()
            await app.server.shouldHaveCreates(0)
            await app.projects.newQuickChat()
            app.projects.shouldShowSession()
            await app.server.shouldHaveCreates(1)
            await app.server.createdPathShouldBe("/home/pi")
        }
    }

    @Test func historyAndRuntimeOpenThroughDifferentIdentities() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            await app.projects.connect()
            await app.projects.openHistory()
            await app.server.openedHistoryShouldBe("/history/saved")
            app.projects.back()
            await app.projects.openRunningSession()
            await app.server.attachedRuntimeShouldBe("running")
        }
    }

    @Test func failedOpenStaysInBrowserWithoutCreatingFallback() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            await app.projects.connect()
            await app.server.rejectOpens()
            await app.projects.openHistory()
            app.projects.shouldBeBrowsing()
            app.projects.shouldShowError(containing: "Not found")
            await app.server.shouldHaveCreates(0)
        }
    }

    @Test func lateCatalogueIsDisplayedAndDuplicateSelectionIsBlocked() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            await app.projects.connect()
            await app.server.publishLateCatalogue()
            try await app.projects.waitForLateProject()
            await app.server.holdOpen()
            try await app.projects.beginOpen()
            await app.projects.openHistory()
            await app.server.shouldHaveOpens(1)
            await app.projects.disconnect()
            await app.server.releaseOpen()
            await app.projects.finishOpen()
            app.projects.shouldNotShowSession()
        }
    }

    @Test func backDoesNotDisconnectAndDraftsDoNotLeakAcrossSessions() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            await app.projects.connect()
            await app.projects.newQuickChat()
            app.chat.enterDraft("Keep here")
            app.projects.back()
            await app.server.shouldBeConnected()
            await app.projects.openHistory()
            app.chat.draftShouldBe("")
            app.projects.back()
            await app.projects.newQuickChat()
            app.chat.draftShouldBe("")
        }
    }

    @Test func unknownOpenOutcomeBlocksRetryUntilExplicitReconnect() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            await app.projects.connect()
            await app.server.loseOpenReceipt()
            await app.projects.openHistory()
            app.projects.shouldShowError(containing: "unknown")
            await app.projects.openHistory()
            await app.server.shouldHaveOpens(1)
        }
    }
}
