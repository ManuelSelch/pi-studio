import FactoryKit
import Foundation
import PiSDK
import Testing
@testable import PiUI

@MainActor
struct SessionDependenciesTests {
    @Test func controllerIsCachedWithinOneScopeOnly() {
        let first = SessionDependencies()
        let second = SessionDependencies()
        #expect(first.sessionController() === first.sessionController())
        #expect(first.sessionController() !== second.sessionController())
        #expect(first.sessionController().configuration.endpoint == SessionConfiguration.development.endpoint)
        #expect(first.sessionController().state.connection == .disconnected)
    }

    @Test func registrationsReachControllerWithoutLeakingToAnotherScope() async {
        let dependencies = SessionDependencies()
        let connection = DependencyConnectionStub()
        let configuration = SessionConfiguration(endpoint: URL(string: "ws://127.0.0.1:9999/ws")!, projectPath: "/tmp/injected")
        dependencies.sessionConfiguration.register { configuration }
        dependencies.makeConnection.register { { _ in connection } }
        let controller = dependencies.sessionController()
        #expect(controller.configuration.endpoint == configuration.endpoint)
        await controller.connect(takingControl: true)
        #expect(await connection.projectPath == configuration.projectPath)
        #expect(controller.state.connection == .ready(.init(sessionId: "injected", projectPath: configuration.projectPath)))
        await controller.disconnect()
        #expect(await connection.closed)
        #expect(SessionDependencies().sessionController().configuration.projectPath == SessionConfiguration.development.projectPath)
    }
}

private actor DependencyConnectionStub: PiDemoConnection {
    var projectPath: String?
    var closed = false
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession {
        self.projectPath = projectPath
        return .init(sessionId: "injected", projectPath: projectPath)
    }
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func projections() async -> AsyncStream<DemoSessionProjection> { AsyncStream { $0.finish() } }
    func send(_ text: String) async throws {}
    func stop() async throws {}
    func disconnect() async { closed = true }
}
