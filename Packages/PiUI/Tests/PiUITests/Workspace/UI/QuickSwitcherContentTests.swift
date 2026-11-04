import FactoryKit
import Flux
import Foundation
import PiSDK
import SwiftUI
import Testing
import ViewInspector
@testable import PiUI

/// Inspects separately constructed quick-switcher content with test callbacks and real stores.
@MainActor
struct QuickSwitcherContentTests {
    @Test func quickSwitcherContentFiltersAndDispatchesTheChosenSession() async throws {
        try await QuickSwitcherContentDriver.run { screen in
            try await screen.launch()

            // The "@" prefix scopes the search to sessions by itself; no filter tap is needed.
            try screen.quickSwitcher.type("@Fix")
            try screen.quickSwitcher.scopeShouldBe(.sessions)
            try await screen.quickSwitcher.choose("Fix the layout")

            try await screen.selectedSessionShouldBe("Fix the layout")
        }
    }
}

/// Drives separately constructed quick-switcher content with a real store and test callbacks.
/// Connection is dispatched directly; this does not exercise container lifecycle or wiring.
@MainActor
private final class QuickSwitcherContentDriver {
    let quickSwitcher: ScreenQuickSwitcherDriver
    private let context: ScreenContext

    private init(catalogue: PiCatalogue, failingFirstConnection: Bool) {
        context = ScreenContext(catalogue: catalogue, failingFirstConnection: failingFirstConnection)
        quickSwitcher = ScreenQuickSwitcherDriver(context)
    }

    /// A default catalogue with one Quick Chats project and one open runtime session.
    static func run(failingFirstConnection: Bool = false,
                    catalogue: PiCatalogue = .screenFixture,
                    _ scenario: (QuickSwitcherContentDriver) async throws -> Void) async throws {
        let driver = QuickSwitcherContentDriver(catalogue: catalogue, failingFirstConnection: failingFirstConnection)
        do {
            try await scenario(driver)
            await driver.context.dispose()
        } catch {
            await driver.context.dispose()
            throw error
        }
    }

    // MARK: Connection

    /// Dispatch a connection request and wait for a catalogue or connection failure.
    func launch(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        context.workspace.dispatch(.connectRequested(takingControl: true))
        try await context.wait("launch connection", sourceLocation: sourceLocation) {
            if !self.context.workspace.state.catalogue.projects.isEmpty { return true }
            if case .failed = self.context.workspace.state.connection { return true }
            return false
        }
    }

    func selectedSessionShouldBe(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("session '\(title)' to be selected", sourceLocation: sourceLocation) {
            self.context.workspace.state.selectedSession?.title == title
        }
    }
}

/// Quick-switcher searches, scope filters and result selection.
@MainActor
private final class ScreenQuickSwitcherDriver {
    private let context: ScreenContext
    private var query = ""

    fileprivate init(_ context: ScreenContext) { self.context = context }

    /// Types into the search field and reads the rendered value back. A scope prefix typed here
    /// ("#", "%", "@", "/") switches the scope by itself, exactly as it does in the app.
    func type(_ value: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        try content().inspect().find(ViewType.TextField.self).setInput(value)
        #expect(query == value, "The search field should report the typed query", sourceLocation: sourceLocation)
        #expect(try content().inspect().find(ViewType.TextField.self).input() == value,
                "The search field should render the typed query", sourceLocation: sourceLocation)
    }

    /// Clicks a result; the real store opens it and the driver waits for the selection.
    func choose(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let button = try content().inspect().find(button: title)
        try button.tap()
        try await context.wait("chosen session '\(title)' to open", sourceLocation: sourceLocation) {
            self.context.workspace.state.selectedSession?.title == title
        }
    }

    /// Checks the query prefix using test-side scope parsing, not the rendered scope selection.
    func scopeShouldBe(_ scope: QuickSwitcherScope, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let rendered = try content().inspect().find(ViewType.TextField.self).input()
        #expect(QuickSwitcherScope.active(for: rendered) == scope,
                "The quick switcher should be scoped to '\(scope.name)', not '\(QuickSwitcherScope.active(for: rendered).name)'",
                sourceLocation: sourceLocation)
    }

    private func content() -> QuickSwitcherContent {
        var presentation = WorkspacePresentation()
        presentation.quickSwitcherOpen = true
        presentation.quickSwitcherQuery = query
        presentation.quickSwitcherItems = QuickSwitcherModel.results(
            catalogue: context.workspace.state.catalogue, query: query)
        var actions = WorkspaceActions(
            open: { _, _ in }, create: { _ in }, connection: {}, settings: {}, back: {},
            draftChanged: { _ in }, send: { _ in }, stop: {}, selectTab: { _ in },
            closeTab: { _ in }, followTailChanged: { _ in }, scrollAnchorChanged: { _ in })
        actions.openQuickSwitcher = {}
        actions.quickSwitcherQueryChanged = { [weak self] value in self?.query = value }
        actions.chooseQuickSwitcherItem = { [weak self] item in
            guard let target = item.target else { return }
            self?.context.workspace.dispatch(.openRequested(target: target, title: item.title))
        }
        return QuickSwitcherContent(presentation: presentation, actions: actions)
    }
}

/// Test-side interpretation of query prefixes; this does not inspect the selected scope.
private enum QuickSwitcherScope: CaseIterable {
    case all, folders, worktrees, sessions, actions

    var prefix: String {
        switch self {
        case .all: ""
        case .folders: "#"
        case .worktrees: "%"
        case .sessions: "@"
        case .actions: "/"
        }
    }
    var name: String {
        switch self {
        case .all: "All"
        case .folders: "Folders"
        case .worktrees: "Worktrees"
        case .sessions: "Sessions"
        case .actions: "Actions"
        }
    }

    /// Mirrors `QuickSwitcherContent`: the first character selects a scope, else All.
    static func active(for query: String) -> QuickSwitcherScope {
        allCases.first { !$0.prefix.isEmpty && query.hasPrefix($0.prefix) } ?? .all
    }
}

@MainActor
private final class ScreenContext {
    let container = Container()
    let connection: ScreenConnection
    let transport = SessionTransport()
    let workspace: FluxStore<WorkspaceFeature>
    let session: FluxStore<SessionFeature>

    init(catalogue: PiCatalogue, failingFirstConnection: Bool) {
        connection = ScreenConnection(catalogue: catalogue, failingFirstConnection: failingFirstConnection)
        let transport = self.transport
        container.endpointSettingsService.register { @MainActor in ScreenSettings() }
        container.makeSessionConnection.register { [connection] in { _ in connection } }
        container.sessionTransport.register { @MainActor in transport }
        workspace = container.workspaceStore()
        session = container.sessionStore()
    }

    func wait(_ description: String, sourceLocation: SourceLocation,
              _ predicate: @escaping () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while ContinuousClock.now < deadline {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for \(description)", sourceLocation: sourceLocation)
        throw ScreenTimeout()
    }

    func dispose() async {
        workspace.dispatch(.disconnectRequested())
        for _ in 0..<200 where workspace.state.connection != .disconnected {
            try? await Task.sleep(for: .milliseconds(5))
        }
        await connection.release()
    }

    struct ScreenTimeout: Error {}
}

@MainActor
private final class ScreenSettings: EndpointSettingsService {
    var value: String?
    func load() -> String? { value }
    func save(_ endpoint: String) throws { value = endpoint }
}

private actor ScreenConnection: PiSessionConnection {
    private let catalogue: PiCatalogue
    private let failingFirstConnection: Bool
    private var connects = 0

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

extension PiCatalogue {
    /// Default screen-driver fixture: one Quick Chats project and one idle runtime session.
    static var screenFixture: PiCatalogue {
        PiCatalogue(
            projects: [.init(path: "/home/pi", name: "Quick Chats", quickChats: true)],
            sessions: [.init(sessionId: "runtime-1", title: "Fix the layout",
                             projectPath: "/home/pi", projectName: "Quick Chats", status: "idle")])
    }
}
