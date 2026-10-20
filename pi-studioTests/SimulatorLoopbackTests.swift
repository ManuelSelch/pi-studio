import Foundation
import PiUI
import Testing

/// Opt-in native acceptance against the host-owned, ephemeral fake-runtime server.
@Test(.enabled(if: ProcessInfo.processInfo.environment["PI_STUDIO_TEST_ENDPOINT"] != nil))
@MainActor func isolatedNativeWebSocketAcceptance() async throws {
    let environment = ProcessInfo.processInfo.environment
    let endpoint = try #require(environment["PI_STUDIO_TEST_ENDPOINT"].flatMap(URL.init(string:)))
    let project = try #require(environment["PI_STUDIO_TEST_PROJECT"])
    try await PiIntegrationDriver.run(configuration: .init(endpoint: endpoint, projectPath: project)) { app in
        try await app.session.connect()
        try await app.chat.sendPrompt("Say hello")
        let partial = try await app.chat.waitForPartialReply(messageCount: 2)
        try await app.session.waitUntilReady()
        app.chat.messagesShouldBe(["Say hello", "Hello from the isolated Swift demo."])
        app.chat.lastReplyShouldDiffer(from: partial)
        app.chat.draftShouldBe("")
        try await app.chat.sendPrompt("Second turn")
        _ = try await app.chat.waitForPartialReply(messageCount: 4)
        await app.chat.stop()
        try await app.session.waitUntilReady()
        app.chat.shouldHaveMessageCount(4)
        _ = try app.chat.captureLastReply()
        let transcript = app.chat.captureTranscript()
        await app.session.disconnect()
        app.session.shouldBeDisconnected()
        app.chat.transcriptShouldBe(transcript)
    }
}
