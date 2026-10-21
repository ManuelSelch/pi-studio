import Testing

/// Slice 2: several independently running server sessions, one workspace connection
/// and one live transcript. Every scenario drives the workspace, never a stub directly.
@Suite @MainActor struct WorkspaceTabsTests {
    @Test func openingTwoSessionsCreatesTwoTabsAndSwitchingRestoresEachDraft() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.tabs.openQuickChat()
            try await app.tabs.openRunningSession()
            app.tabs.shouldShow(["New chat", "Working"])
            app.tabs.shouldSelect("Working")
            app.tabs.transcriptShouldBe(["Answer from running"])
            app.tabs.draftShouldBe("")
            app.tabs.enterDraft("Draft for working")
            try await app.tabs.select("New chat")
            app.tabs.transcriptShouldBe(["Answer from new-1"])
            app.tabs.draftShouldBe("")
            app.tabs.enterDraft("Draft for the chat")
            try await app.tabs.select("Working")
            app.tabs.draftShouldBe("Draft for working")
            try await app.tabs.select("New chat")
            app.tabs.draftShouldBe("Draft for the chat")
            // Switching is local: it never sends, stops or reopens server work.
            await app.server.shouldHaveSends(0)
            await app.server.shouldHaveStops(0)
        }
    }

    @Test func reopeningTheSameRuntimeSelectsItsExistingTab() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.tabs.openRunningSession()
            app.tabs.enterDraft("Keep me")
            try await app.tabs.openHistory()
            try await app.tabs.openRunningSession()
            app.tabs.shouldShow(["Working", "Saved"])
            app.tabs.shouldSelect("Working")
            app.tabs.draftShouldBeRetained("Keep me", for: "Working")
        }
    }

    @Test func closingATabSelectsTheNeighbourAndKeepsItsRuntimeRunning() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.tabs.openQuickChat()
            try await app.tabs.openRunningSession()
            try await app.tabs.close("Working")
            app.tabs.shouldShow(["New chat"])
            app.tabs.shouldSelect("New chat")
            // R8: closing a view is local. The runtime keeps running on the server.
            await app.server.shouldHaveStops(0)
            await app.server.shouldHaveSends(0)
            await app.server.shouldBeConnected()
            try await app.tabs.close("New chat")
            app.tabs.shouldHaveNoTabs()
            app.tabs.shouldSelect(nil)
            await app.server.shouldBeConnected()
        }
    }

    @Test func switchingIsAllowedWhileAnotherSessionIsGenerating() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.tabs.openRunningSession()
            app.tabs.shouldBeGenerating()
            try await app.tabs.openQuickChat()
            app.tabs.shouldSelect("New chat")
            // The running session stays observable and running in the background.
            try await app.tabs.select("Working")
            app.tabs.shouldBeGenerating()
            app.tabs.transcriptShouldBe(["Answer from running"])
            await app.server.shouldHaveStops(0)
        }
    }

    @Test func lateSelectionResultCannotOverwriteTheNewestChoice() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.tabs.openQuickChat()
            try await app.tabs.openRunningSession()
            await app.server.holdAttach()
            app.tabs.beginSelect("New chat")
            try await app.server.waitForHeldAttach()
            try await app.tabs.select("Working")
            await app.server.releaseAttach()
            await app.tabs.finishSelecting()
            // The held answer for the older choice is discarded, not rendered.
            app.tabs.shouldSelect("Working")
            app.tabs.observedRuntimeShouldBe("running")
            app.tabs.transcriptShouldBe(["Answer from running"])
        }
    }

    @Test func aServerClosedRuntimeRemovesItsTabAndKeepsTheWorkspaceUsable() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.tabs.openQuickChat()
            try await app.tabs.openRunningSession()
            await app.server.closeRuntime("running")
            try await app.tabs.waitForSelected("New chat")
            app.tabs.shouldShow(["New chat"])
            try await app.tabs.waitForObservedRuntime("new-1")
            await app.server.shouldBeConnected()
        }
    }

    @Test func aReplacedRuntimeKeepsItsTabDraftAndOrder() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.tabs.openQuickChat()
            try await app.tabs.openRunningSession()
            try await app.tabs.select("Working")
            app.tabs.enterDraft("Typed before the swap")
            await app.server.replaceRuntime("running", with: "running-2")
            try await app.tabs.waitForRuntime("running-2", for: "Working")
            app.tabs.shouldShow(["New chat", "Working"])
            app.tabs.draftShouldBeRetained("Typed before the swap", for: "Working")
            try await app.tabs.select("New chat")
            try await app.tabs.select("Working")
            try await app.tabs.waitForObservedRuntime("running-2")
            app.tabs.transcriptShouldBe(["Answer from running-2"])
            app.tabs.shouldBeGenerating()
        }
    }
}
