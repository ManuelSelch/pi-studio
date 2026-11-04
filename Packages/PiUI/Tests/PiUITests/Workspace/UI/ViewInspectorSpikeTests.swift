import FactoryKit
import Flux
import Foundation
import PiSDK
import SwiftUI
import Testing
import ViewInspector
@testable import PiUI

/// Spike: ViewInspector drives the real `WorkspaceContainer` and its store wiring in-process,
/// so the screens that are exercised for real also report coverage through `swift test`.
/// Both scenarios click buttons, type into a text field and wait for async middleware state.
@MainActor
@Suite(.serialized)
struct ViewInspectorSpikeTests {
    @MainActor final class Fixture {
        let container = Container()
        let connection: SpikeConnection
        let transport = SessionTransport()
        init(catalogue: PiCatalogue, failFirstConnect: Bool = false) {
            connection = SpikeConnection(catalogue: catalogue, failFirstConnect: failFirstConnect)
            let transport = self.transport
            container.endpointSettingsService.register { @MainActor in SpikeSettings() }
            container.makeSessionConnection.register { [connection] in { _ in connection } }
            container.sessionTransport.register { @MainActor in transport }
            workspace = container.workspaceStore()
            session = container.sessionStore()
        }
        let workspace: FluxStore<WorkspaceFeature>
        let session: FluxStore<SessionFeature>

        /// The app resolves `@InjectedObject` from the shared task-local container; scope it.
        func withContainer<T>(_ body: () -> T) -> T {
            Container.$shared.withValue(container, operation: body)
        }

        func connect(sourceLocation: SourceLocation = #_sourceLocation) async throws {
            workspace.dispatch(.connectRequested(takingControl: true))
            try await settle("connection", sourceLocation) {
                if !self.workspace.state.catalogue.projects.isEmpty { return true }
                if case .failed = self.workspace.state.connection { return true }
                return false
            }
        }

        func settle(_ what: String, _ sourceLocation: SourceLocation = #_sourceLocation,
                    _ predicate: @escaping () -> Bool) async throws {
            let deadline = ContinuousClock.now.advanced(by: .seconds(4))
            while ContinuousClock.now < deadline {
                if predicate() { return }
                try await Task.sleep(for: .milliseconds(5))
            }
            Issue.record("Timed out waiting for \(what)", sourceLocation: sourceLocation)
        }
    }

    /// A failed connection shows a retry button; tapping it reconnects and clears the error.
    @Test func retryFromHomeReconnectsAndClearsTheError() async throws {
        let fixture = Fixture(catalogue: Self.catalogue, failFirstConnect: true)
        try await fixture.connect()
        #expect(fixture.workspace.state.error != nil)

        let tapped = fixture.withContainer { () -> Bool in
            let view = WorkspaceContainer(onOpenSettings: {})
            guard let button = try? view.inspect().find(button: "Try again") else { return false }
            try? button.tap()
            return true
        }
        #expect(tapped, "The Home retry button was not reachable")

        try await fixture.settle("reconnection") {
            !fixture.workspace.state.catalogue.projects.isEmpty && fixture.workspace.state.error == nil
        }
        let stillHasError = fixture.withContainer {
            let view = WorkspaceContainer(onOpenSettings: {})
            return (try? view.inspect().find(button: "Try again")) != nil
        }
        #expect(!stillHasError)
    }

    /// Typing filters the quick switcher; clicking a result opens that session asynchronously.
    @Test func quickSwitcherFiltersTypedTextAndOpensTheChosenSession() async throws {
        let fixture = Fixture(catalogue: Self.catalogue)
        try await fixture.connect()

        var typed = ""
        var filters = 0
        var chosen: QuickSwitcherModel.Item?
        var presentation = WorkspacePresentation()
        presentation.quickSwitcherOpen = true
        let results = QuickSwitcherModel.results(catalogue: fixture.workspace.state.catalogue, query: "")
        presentation.quickSwitcherItems = results
        let actions = fixture.actions(
            quickSwitcherQueryChanged: { typed = $0 },
            chooseQuickSwitcherItem: { item in
                chosen = item
                guard let target = item.target else { return }
                fixture.workspace.dispatch(.openRequested(target: target, title: item.title))
            },
            filters: { filters += 1 })

        let switcher = QuickSwitcherContent(presentation: presentation, actions: actions)
        try switcher.inspect().find(ViewType.TextField.self).setInput("@Fix")
        #expect(typed == "@Fix")
        #expect(filters == 1)

        try switcher.inspect().find(button: "@ Sessions").tap()
        #expect(typed == "@")

        let result = try #require(results.first, "The fixture catalogue must yield a session result")
        try switcher.inspect().find(button: result.title).tap()
        #expect(chosen?.id == result.id)

        try await fixture.settle("session opened") { fixture.workspace.state.selectedSessionId != nil }
    }

    // MARK: Fixtures

    private static let catalogue = PiCatalogue(
        projects: [.init(path: "/home/pi", name: "Quick Chats", quickChats: true)],
        sessions: [.init(sessionId: "runtime-1", title: "Fix the layout",
                         projectPath: "/home/pi", projectName: "Quick Chats", status: "idle")])
}

@MainActor
extension ViewInspectorSpikeTests.Fixture {
    /// Switcher actions assembled over the real store; only the exercised callbacks are captured.
    func actions(quickSwitcherQueryChanged: @escaping @MainActor (String) -> Void,
                 chooseQuickSwitcherItem: @escaping @MainActor (QuickSwitcherModel.Item) -> Void,
                 filters: @escaping @MainActor () -> Void) -> WorkspaceActions {
        var value = WorkspaceActions(
            open: { _, _ in }, create: { _ in }, connection: {}, settings: {}, back: {},
            draftChanged: { _ in }, send: { _ in }, stop: {}, selectTab: { _ in },
            closeTab: { _ in }, followTailChanged: { _ in }, scrollAnchorChanged: { _ in })
        value.openQuickSwitcher = { filters() }
        value.quickSwitcherQueryChanged = { query in filters(); quickSwitcherQueryChanged(query) }
        value.chooseQuickSwitcherItem = chooseQuickSwitcherItem
        return value
    }
}

@MainActor private final class SpikeSettings: EndpointSettingsService {
    var value: String?
    func load() -> String? { value }
    func save(_ endpoint: String) throws { value = endpoint }
}

actor SpikeConnection: PiSessionConnection {
    private let catalogue: PiCatalogue
    private let failFirstConnect: Bool
    private var connectCount = 0

    init(catalogue: PiCatalogue, failFirstConnect: Bool) {
        self.catalogue = catalogue
        self.failFirstConnect = failFirstConnect
    }

    func connect(takingControl: Bool) async throws {
        connectCount += 1
        if failFirstConnect && connectCount == 1 { throw PiError.invalidState }
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
}
