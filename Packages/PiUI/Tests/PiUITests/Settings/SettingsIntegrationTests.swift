import Testing

/// Endpoint policy: a saved endpoint applies to the next explicit Connect only, and never
/// disturbs the connection or the conversation that is already open.
@MainActor
struct SettingsIntegrationTests {
    @Test func savedEndpointAppliesToTheNextConnectionOnly() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.settings.open()
            app.settings.enterEndpoint("ws://first.test/ws")
            app.settings.save()
            try await app.settings.waitUntilSaved("ws://first.test/ws")
            try await app.projects.connect()
            try await app.tabs.openQuickChat()
            try await app.settings.open()
            app.settings.enterEndpoint("wss://second.test/custom")
            app.settings.save()
            try await app.settings.waitUntilSaved("wss://second.test/custom")
            // The live connection and transcript are untouched until an explicit reconnect.
            await app.server.connectionEndpointsShouldBe(["ws://first.test/ws"])
            app.tabs.transcriptShouldBe(["Answer from new-1"])
            await app.projects.disconnect()
            try await app.server.waitForDisconnected()
            try await app.projects.connect()
            await app.server.connectionEndpointsShouldBe(["ws://first.test/ws", "wss://second.test/custom"])
        }
    }

    @Test func invalidEndpointIsRejectedWithoutSaving() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.settings.open()
            app.settings.enterEndpoint("https://example.com/ws")
            app.settings.save()
            try await app.settings.waitUntilSettled()
            app.settings.shouldShowError(containing: "ws://")
            try await app.settings.shouldBePresented(true)
            app.settings.cancel()
            try await app.settings.shouldBePresented(false)
        }
    }

    @Test func duplicateOpenPreservesTheActiveFlowAndDraft() async throws {
        try await WorkspaceIntegrationDriver.run { app in
            try await app.settings.open()
            app.settings.enterEndpoint("ws://draft.test/ws")
            try await app.settings.open()
            try await app.settings.shouldBePresented(true)
            app.settings.draftShouldBe("ws://draft.test/ws")
            app.settings.cancel()
            try await app.settings.shouldBePresented(false)
        }
    }
}
