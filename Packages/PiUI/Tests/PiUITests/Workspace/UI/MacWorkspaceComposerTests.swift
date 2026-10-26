#if os(macOS)
import AppKit
import FactoryKit
import Flux
import Foundation
import PiSDK
import SwiftUI
import Testing
@testable import PiUI

/// The whole macOS path: the real `WorkspaceContainer` on one scoped connection, connect,
/// open a session, then type into the hosted composer. macOS XCUITest cannot read this app's
/// accessibility tree in this environment, so the container is hosted in-process instead.
extension MacComposerTests {
@MainActor
struct MacWorkspaceComposerTests {
    @MainActor private final class Fixture {
        let container = Container()
        let connection = MacWorkspaceConnectionStub()
        let transport = SessionTransport()
        init() {
            let transport = self.transport
            container.endpointSettingsService.register { @MainActor in MacMemorySettings() }
            container.makeSessionConnection.register { [connection] in { _ in connection } }
            container.sessionTransport.register { @MainActor in transport }
            workspace = container.workspaceStore()
            session = container.sessionStore()
        }
        let workspace: FluxStore<WorkspaceFeature>
        let session: FluxStore<SessionFeature>

        func host() -> MacComposerDriver {
            MacComposerDriver(WorkspaceContainerProbe(store: workspace, session: session), width: 900)
        }

        func wait(_ description: String, sourceLocation: SourceLocation = #_sourceLocation,
                  _ condition: @escaping () -> Bool) async throws {
            let deadline = ContinuousClock.now.advanced(by: .seconds(4))
            while ContinuousClock.now < deadline {
                if condition() { return }
                try await Task.sleep(for: .milliseconds(5))
            }
            Issue.record("macOS workspace did not settle: \(description)", sourceLocation: sourceLocation)
        }
    }

    /// Mirrors the container's own mapping: the composer takes the selected tab's draft.
    private struct WorkspaceContainerProbe: View {
        @ObservedObject var store: FluxStore<WorkspaceFeature>
        @ObservedObject var session: FluxStore<SessionFeature>
        var body: some View {
            var presentation = SessionPresentation()
            presentation.draft = store.state.draft
            presentation.canEditMessage = session.state.canEditMessage
            presentation.canSend = session.state.canSend
            presentation.placeholder = "Start a conversation."
            return SessionScreen(presentation: presentation,
                                 onDraftChanged: { store.dispatch(.draftChanged($0)) },
                                 onConnect: {}, onDisconnect: {}, onSend: { _ in }, onStop: {},
                                 showsHeader: false, maxContentWidth: 760)
        }
    }

    @Test func aSessionOpenedThroughTheWorkspaceAcceptsTyping() async throws {
        let fixture = Fixture()
        let hosting = fixture.host()
        fixture.workspace.dispatch(.connectRequested(takingControl: true))
        try await fixture.wait("catalogue") { !fixture.workspace.state.catalogue.projects.isEmpty }
        fixture.workspace.dispatch(.createRequested(projectPath: "/home/pi", title: "New chat"))
        try await fixture.wait("attached session") {
            fixture.workspace.state.observedRuntimeId != nil && fixture.session.state.canEditMessage
        }
        try await hosting.settle()
        try hosting.editingShouldBeEnabled(true)
        try hosting.wholeWidthShouldAcceptClicks()
        try await hosting.type("hello")
        #expect(fixture.workspace.state.draft == "hello")
        try hosting.textShouldBe("hello")
    }
}
}

@MainActor private final class MacMemorySettings: EndpointSettingsService {
    var value: String?
    func load() -> String? { value }
    func save(_ endpoint: String) throws { value = endpoint }
}

private actor MacWorkspaceConnectionStub: PiSessionConnection {
    var closed = false
    func connect(takingControl: Bool) async throws { guard takingControl else { throw PiError.invalidState } }
    func catalogues() async -> AsyncStream<PiCatalogue> {
        let catalogue = PiCatalogue(projects: [.init(path: "/home/pi", name: "Quick Chats", quickChats: true)])
        return AsyncStream { $0.yield(catalogue) }
    }
    func sessionEvents() async -> AsyncStream<PiSessionEvent> { AsyncStream { $0.finish() } }
    func createSession(projectPath: String) async throws -> DemoSession {
        DemoSession(sessionId: "new-1", projectPath: projectPath)
    }
    func attachSession(sessionId: String) async throws -> DemoSession {
        DemoSession(sessionId: sessionId, projectPath: "/home/pi")
    }
    func openSession(sessionPath: String) async throws -> DemoSession {
        DemoSession(sessionId: "saved", projectPath: "/home/pi")
    }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession { throw PiError.invalidState }
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func projections() async -> AsyncStream<DemoSessionProjection> {
        let projection = DemoSessionProjection(session: .init(sessionId: "new-1", projectPath: "/home/pi"), status: .idle)
        return AsyncStream { $0.yield(projection) }
    }
    func send(_ text: String) async throws {}
    func stop() async throws {}
    func disconnect() async { closed = true }
}
#endif
