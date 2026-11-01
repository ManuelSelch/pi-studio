import Foundation
import PiUI
import Testing

/// Opt-in native acceptance against the host-owned, ephemeral fake-runtime server.
@Test(.enabled(if: ProcessInfo.processInfo.environment["PI_STUDIO_TEST_ENDPOINT"] != nil))
@MainActor func isolatedNativeWebSocketAcceptance() async throws {
    let environment = ProcessInfo.processInfo.environment
    let endpoint = try #require(environment["PI_STUDIO_TEST_ENDPOINT"].flatMap(URL.init(string:)))
    let project = try #require(environment["PI_STUDIO_TEST_PROJECT"])
    try await WorkspaceIntegrationDriver.run(endpoint: endpoint) { app in
        try await app.projects.connect()
        try await app.projects.createSession(projectPath: project)
        try await app.chat.sendPrompt("Say hello")
        let partial = try await app.chat.waitForPartialReply(messageCount: 2)
        try await app.chat.waitUntilReady()
        app.chat.messagesShouldBe(["Say hello", "Hello from the isolated Swift demo."])
        app.chat.lastReplyShouldDiffer(from: partial)
        app.chat.clearInstructionShouldBe("Say hello")
        try await app.chat.sendPrompt("Second turn")
        _ = try await app.chat.waitForPartialReply(messageCount: 4)
        app.chat.stop()
        try await app.chat.waitUntilReady()
        app.chat.shouldHaveMessageCount(4)
        _ = try app.chat.captureLastReply()
        let transcript = app.chat.captureTranscript()
        await app.projects.disconnect()
        try await app.server.waitForDisconnected()
        app.chat.shouldBeDisconnected()
        app.chat.transcriptShouldBe(transcript)
    }
}
