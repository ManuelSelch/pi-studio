import Foundation
import PiSDK
import Testing

/// Opt-in test against a host-started, ephemeral fake-runtime server. Normal
/// unit/UI tests never connect to the development backend or use real models.
@Test(.enabled(if: ProcessInfo.processInfo.environment["PI_STUDIO_TEST_ENDPOINT"] != nil))
func isolatedSimulatorWebSocketAcceptance() async throws {
    let environment = ProcessInfo.processInfo.environment
    let endpoint = try #require(environment["PI_STUDIO_TEST_ENDPOINT"].flatMap(URL.init(string:)))
    let project = try #require(environment["PI_STUDIO_TEST_PROJECT"])
    let client = PiClient(endpoint: endpoint)
    _ = try await client.connectDemo(projectPath: project, takingControl: true)
    do {
        try await client.send("Say hello")
        try await poll { await client.projection?.messages.last?.isPartial == true }
        let partial = await client.projection?.messages.last?.text
        try await poll { await client.projection?.status == .idle }
        #expect(await client.projection?.messages.map(\.text) == ["Say hello", "Hello from the isolated Swift demo."])
        #expect(partial != "Hello from the isolated Swift demo.")
        try await client.send("Second turn")
        try await poll { await client.projection?.messages.last?.isPartial == true }
        try await client.stop()
        try await poll { await client.projection?.status == .idle }
        try await Task.sleep(for: .milliseconds(150))
        #expect(await client.projection?.messages.count == 4)
        #expect(await client.projection?.messages.last?.text.isEmpty == false)
        await client.disconnect()
        #expect(await client.state == .disconnected)
    } catch {
        await client.disconnect()
        throw error
    }
}

private func poll(_ predicate: () async -> Bool) async throws {
    for _ in 0..<400 {
        if await predicate() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw PiError.requestExpired(outcomeUnknown: false)
}
