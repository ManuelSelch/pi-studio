import FactoryKit
import Flux
import Foundation
import PiSDK
import Testing
#if os(macOS)
import AppKit
import SwiftUI
import ViewInspector
#endif
@testable import PiUI

/// The composer is locked in several states; each one has to say so, because a locked Mac
/// editor looks identical to an editable one.
@MainActor
struct WorkspaceContainerTests {
    private let container = WorkspaceContainer(onOpenSettings: {})

    private func state(status: DemoRunStatus?, connection: PiConnectionState = .ready(.init(sessionId: "s", projectPath: "/p")),
                       sending: Bool = false, stopping: Bool = false) -> SessionFeature.State {
        var state = SessionFeature.State()
        state.connection = connection
        state.projection = status.map { DemoSessionProjection(session: .init(sessionId: "s", projectPath: "/p"), status: $0) }
        state.isSending = sending
        state.isStopping = stopping
        return state
    }

    #if os(macOS)
    @Test func mountedContainerConnectsOnLaunch() async throws {
        try await WorkspaceContainerDriver.run { workspace in
            try await workspace.launchShouldConnect()
        }
    }

    @Test func failedLaunchCanBeRetriedFromHome() async throws {
        try await WorkspaceContainerDriver.run(failingFirstConnection: true) { workspace in
            try await workspace.launchShouldFail()
            workspace.homeShouldShowConnectionError()

            try await workspace.retryFromHome()
            workspace.homeShouldShowGreeting()
        }
    }
    #endif

    @Test func anIdleSessionNeedsNoHint() {
        #expect(container.composerHint(state(status: .idle)).isEmpty)
    }

    @Test func everyLockedStateExplainsItself() {
        #expect(container.composerHint(state(status: .running)).contains("Generating"))
        #expect(container.composerHint(state(status: .starting)).contains("Sending"))
        #expect(container.composerHint(state(status: .aborting)).contains("Stopping"))
        #expect(container.composerHint(state(status: .idle, sending: true)).contains("Sending"))
        #expect(container.composerHint(state(status: .idle, stopping: true)).contains("Stopping"))
        #expect(container.composerHint(state(status: nil, connection: .connecting)).contains("Waiting"))
        #expect(container.composerHint(state(status: nil, connection: .disconnected)).contains("No session"))
    }
}

#if os(macOS)
/// Hosts the actual container off-screen within its isolated dependency scope.
@MainActor
private final class WorkspaceContainerDriver {
    private let container: Container
    private let connection: HostedWorkspaceConnection
    private let window: NSWindow
    private let hosting: NSHostingView<WorkspaceContainer>
    private let store: FluxStore<WorkspaceFeature>

    private init(container: Container, failingFirstConnection: Bool) {
        self.container = container
        let catalogue = PiCatalogue(projects: [.init(path: "/home/pi", name: "Quick Chats", quickChats: true)])
        connection = HostedWorkspaceConnection(catalogue: catalogue, failingFirstConnection: failingFirstConnection)
        container.endpointSettingsService.register { @MainActor in HostedWorkspaceSettings() }
        container.makeSessionConnection.register { [connection] in { _ in connection } }
        let transport = SessionTransport()
        container.sessionTransport.register { @MainActor in transport }
        store = container.workspaceStore()
        hosting = NSHostingView(rootView: WorkspaceContainer(onOpenSettings: {}))
        hosting.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
    }

    static func run(failingFirstConnection: Bool = false,
                    _ scenario: (WorkspaceContainerDriver) async throws -> Void) async throws {
        let dependencies = Container()
        try await Container.$shared.withValue(dependencies) {
            // Construct and host inside the active dependency scope.
            let driver = WorkspaceContainerDriver(container: dependencies, failingFirstConnection: failingFirstConnection)
            do {
                try await scenario(driver)
                await driver.dispose()
            } catch {
                await driver.dispose()
                throw error
            }
        }
    }

    func launchShouldConnect(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await wait("launch connection", sourceLocation: sourceLocation) {
            !self.store.state.catalogue.projects.isEmpty
        }
        let count = await connection.connects
        #expect(count == 1, "Mounting should request one connection", sourceLocation: sourceLocation)
    }

    func launchShouldFail(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await wait("launch failure", sourceLocation: sourceLocation) {
            if case .failed = self.store.state.connection { return true }
            return false
        }
    }

    func homeShouldShowConnectionError(sourceLocation: SourceLocation = #_sourceLocation) {
        let shown = (try? hosting.rootView.inspect().find(viewWithAccessibilityIdentifier: "homeConnectionError")) != nil
        #expect(shown, "Home should show the connection error", sourceLocation: sourceLocation)
    }

    func homeShouldShowGreeting(sourceLocation: SourceLocation = #_sourceLocation) {
        let shown = (try? hosting.rootView.inspect().find(viewWithAccessibilityIdentifier: "homeGreeting")) != nil
        #expect(shown, "Home should show the greeting", sourceLocation: sourceLocation)
    }

    func retryFromHome(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let button = try hosting.rootView.inspect().find(button: "Try again")
        try button.tap()
        try await wait("reconnection", sourceLocation: sourceLocation) {
            !self.store.state.catalogue.projects.isEmpty && self.store.state.error == nil
        }
    }

    private func wait(_ description: String, sourceLocation: SourceLocation,
                      _ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while ContinuousClock.now < deadline {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for \(description)", sourceLocation: sourceLocation)
        throw Timeout()
    }

    private func dispose() async {
        window.contentView = nil
        store.dispatch(.disconnectRequested())
        await connection.release()
    }

    private struct Timeout: Error {}
}

@MainActor
private final class HostedWorkspaceSettings: EndpointSettingsService {
    var value: String?
    func load() -> String? { value }
    func save(_ endpoint: String) throws { value = endpoint }
}

private actor HostedWorkspaceConnection: PiSessionConnection {
    private let catalogue: PiCatalogue
    private let failingFirstConnection: Bool
    private(set) var connects = 0

    init(catalogue: PiCatalogue, failingFirstConnection: Bool) {
        self.catalogue = catalogue
        self.failingFirstConnection = failingFirstConnection
    }

    func connect(takingControl: Bool) async throws {
        connects += 1
        if failingFirstConnection && connects == 1 { throw PiError.invalidState }
    }
    func catalogues() async -> AsyncStream<PiCatalogue> { AsyncStream { $0.yield(catalogue) } }
    func sessionEvents() async -> AsyncStream<PiSessionEvent> { AsyncStream { $0.finish() } }
    func createSession(projectPath: String) async throws -> DemoSession { DemoSession(sessionId: "new", projectPath: projectPath) }
    func attachSession(sessionId: String) async throws -> DemoSession { DemoSession(sessionId: sessionId, projectPath: "/home/pi") }
    func openSession(sessionPath: String) async throws -> DemoSession { DemoSession(sessionId: "saved", projectPath: "/home/pi") }
    func archiveSession(path: String) async throws { throw PiError.invalidState }
    func closeSession(sessionId: String) async throws {}
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession { throw PiError.invalidState }
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func projections() async -> AsyncStream<DemoSessionProjection> { AsyncStream { $0.finish() } }
    func send(_ text: String) async throws {}
    func stop() async throws {}
    func disconnect() async {}
    func release() async {}
}

#endif
