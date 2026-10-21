import Testing

/// Slice 3: the iPhone switches open sessions through an overview sheet, with no tab strip.
/// Every scenario drives the workspace, and the rows come from the container's own mapping.
@Suite @MainActor struct SessionOverviewTests {
    @Test func switchingThreeSessionsThroughTheOverviewKeepsDraftsAndTranscriptsApart() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.tabs.openQuickChat()
            app.tabs.enterDraft("Draft for the new chat")
            app.overview.backToProjects()

            try await app.tabs.openHistory()
            app.tabs.enterDraft("Draft for the saved one")
            app.overview.backToProjects()

            try await app.tabs.openRunningSession()

            // The overview lists every open session in open order, with its project, and the
            // conversation that is actually on screen is the selected one.
            app.overview.shouldShow(["New chat", "Saved", "Working"])
            app.overview.shouldShowProjects(["/home/pi", "/repo", "/repo"])
            app.overview.shouldSelect("Working")
            app.overview.activityShouldBe(.running, for: "Working")

            // Leaving the conversation to browse projects changes no open session.
            app.overview.backToProjects()
            app.overview.shouldSelect(nil)
            app.overview.shouldShow(["New chat", "Saved", "Working"])

            try await app.overview.select("Saved")
            app.tabs.draftShouldBe("Draft for the saved one")
            app.tabs.transcriptShouldBe(["Answer from saved"])
            try await app.overview.select("New chat")
            app.tabs.draftShouldBe("Draft for the new chat")
            app.tabs.transcriptShouldBe(["Answer from new-1"])

            // Switching and browsing are local: nothing reaches the server.
            await app.server.shouldHaveSends(0)
            await app.server.shouldHaveStops(0)
            // One history open and one create: the running session is attached, not reopened.
            await app.server.shouldHaveOpens(1)
            await app.server.shouldHaveCreates(1)
        }
    }

    @Test func closingTheLastOpenViewReturnsToProjectsWithoutDisconnecting() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            try await app.tabs.openQuickChat()
            app.overview.shouldShow(["New chat"])

            try await app.overview.close("New chat")

            app.overview.shouldBeEmpty()
            app.overview.shouldSelect(nil)
            app.projects.shouldBeBrowsing()
            // The connection and the catalogue survive an empty workspace.
            await app.server.shouldBeConnected()
            app.overview.newSessionPath.shouldBe("/home/pi")
        }
    }

    @Test func theOverviewStartsANewSessionInQuickChats() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.projects.connect()
            let path = try #require(app.overview.newSessionPath)
            #expect(path == "/home/pi")
            try await app.projects.createSession(projectPath: path)
            app.overview.shouldShow(["New chat"])
            app.overview.shouldSelect("New chat")
            app.overview.shouldShowProjects([path])
        }
    }
}

private extension Optional where Wrapped == String {
    func shouldBe(_ expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(self == expected, sourceLocation: sourceLocation)
    }
}
