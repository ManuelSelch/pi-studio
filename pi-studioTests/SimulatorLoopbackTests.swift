import Foundation
import PiSDK
import PiUI
import Testing

/// Opt-in native app test against a host-started, ephemeral fake-runtime server.
/// Normal suites never connect to the development backend or use real models.
@Test(.enabled(if: ProcessInfo.processInfo.environment["PI_STUDIO_TEST_ENDPOINT"] != nil))
@MainActor func isolatedNativeWebSocketAcceptance() async throws {
    let environment = ProcessInfo.processInfo.environment
    let endpoint = try #require(environment["PI_STUDIO_TEST_ENDPOINT"].flatMap(URL.init(string:)))
    let project = try #require(environment["PI_STUDIO_TEST_PROJECT"])
    let controller = SessionController(configuration: .init(endpoint: endpoint, projectPath: project))
    await controller.connect(takingControl: true)
    do {
        try await poll { controller.state.canEditMessage }
        controller.setDraft("Say hello")
        await controller.send()
        try #require(controller.state.errorMessage == nil)
        try await poll { controller.state.projection?.messages.last?.isPartial == true }
        let partial = controller.state.projection?.messages.last?.text
        try await poll { controller.state.projection?.status == .idle }
        #expect(controller.state.projection?.messages.map(\.text) == ["Say hello", "Hello from the isolated Swift demo."])
        #expect(partial != "Hello from the isolated Swift demo.")
        #expect(controller.state.draft.isEmpty)
        controller.setDraft("Second turn")
        await controller.send()
        try #require(controller.state.errorMessage == nil)
        try await poll {
            controller.state.canStop && controller.state.projection?.messages.count == 4
                && controller.state.projection?.messages.last?.isPartial == true
        }
        await controller.stop()
        try await poll { controller.state.projection?.status == .idle }
        try await Task.sleep(for: .milliseconds(150))
        #expect(controller.state.projection?.messages.count == 4)
        #expect(controller.state.projection?.messages.last?.text.isEmpty == false)
        let messages = controller.state.projection?.messages
        await controller.disconnect()
        #expect(controller.state.connection == .disconnected)
        #expect(controller.state.projection?.messages == messages)
    } catch {
        await controller.disconnect()
        throw error
    }
}

@MainActor private func poll(_ predicate: () -> Bool) async throws {
    for _ in 0..<400 {
        if predicate() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    throw PiError.requestExpired(outcomeUnknown: false)
}
