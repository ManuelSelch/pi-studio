import Testing

@MainActor
struct SettingsIntegrationTests {
    @Test func cachedStoreUsesSavedEndpointOnNextConnectionOnly() async throws {
        try await PiIntegrationDriver.run { app in
            app.settings.open()
            app.settings.enterEndpoint("ws://first.test/ws")
            app.settings.save()
            try await app.session.beginConnect()
            app.session.endpointShouldBe("ws://first.test/ws")
            app.settings.open()
            app.settings.enterEndpoint("wss://second.test/custom")
            app.settings.save()
            app.session.shouldBeConnecting()
            app.session.endpointShouldBe("ws://first.test/ws")
            await app.server.connectionEndpointsShouldBe(["ws://first.test/ws"])
            try await app.server.acceptConnection()
            app.session.shouldBeReady()
            try await app.server.streamReply("Untouched streaming reply")
            app.settings.open()
            app.settings.enterEndpoint("ws://third.test/ws")
            app.settings.save()
            app.session.statusShouldBe("Generating…")
            app.chat.messagesShouldBe(["Untouched streaming reply"])
            app.session.endpointShouldBe("ws://first.test/ws")
            await app.server.connectionEndpointsShouldBe(["ws://first.test/ws"])
            await app.session.disconnect()
            try await app.session.connect()
            app.session.endpointShouldBe("ws://third.test/ws")
            await app.server.connectionEndpointsShouldBe(["ws://first.test/ws", "ws://third.test/ws"])
            await app.server.projectPathShouldBe("/tmp/pi-studio-demo")
        }
    }
}
