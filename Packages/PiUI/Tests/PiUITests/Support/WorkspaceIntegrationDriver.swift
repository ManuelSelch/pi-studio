import FactoryKit
import Flux
import Foundation
import PiSDK
import Router
import Synchronization
import Testing
@testable import PiUI

/// Workspace-level test API: connection consent, browsing, open tabs and switching.
/// It drives the real workspace and conversation stores through the same container wiring
/// the app uses, so the middleware bridge between them is exercised, not simulated.
@MainActor
final class WorkspaceIntegrationDriver {
    let projects: WorkspaceProjectsDriver
    let tabs: WorkspaceTabsDriver
    let overview: WorkspaceOverviewDriver
    let settings: WorkspaceSettingsDriver
    let chat: WorkspaceConversationDriver
    let server: WorkspaceServerDriver
    private let context: WorkspaceContext

    private init(endpoint: URL?) {
        let context = WorkspaceContext(endpoint: endpoint)
        self.context = context
        projects = WorkspaceProjectsDriver(context)
        tabs = WorkspaceTabsDriver(context)
        overview = WorkspaceOverviewDriver(context)
        settings = WorkspaceSettingsDriver(context)
        chat = WorkspaceConversationDriver(context)
        server = WorkspaceServerDriver(context)
    }

    /// A nil endpoint uses the isolated stub; an explicit one opts into a real transport.
    static func run(endpoint: URL? = nil,
                    _ scenario: (WorkspaceIntegrationDriver) async throws -> Void) async throws {
        let app = WorkspaceIntegrationDriver(endpoint: endpoint)
        do {
            try await scenario(app)
            await app.context.dispose()
        } catch {
            await app.context.dispose()
            throw error
        }
    }

    var workspace: WorkspaceFeature.State { context.workspace.state }
    var conversation: SessionFeature.State { context.session.state }
}

@MainActor
fileprivate final class WorkspaceContext {
    let container = Container()
    let stub = WorkspaceConnectionStub()
    let endpoint = MemoryWorkspaceEndpointSettings()

    let endpointLog = EndpointLog()

    init(endpoint: URL? = nil) {
        container.endpointSettingsService.register { @MainActor [settings = self] in settings.endpoint }
        if let endpoint {
            endpointLog.values.withLock { $0.append(endpoint.absoluteString) }
            container.makeSessionConnection.register { { url in
                self.endpointLog.values.withLock { $0.append(url.absoluteString) }
                return PiClient(endpoint: url)
            } }
        } else {
            container.makeSessionConnection.register { [stub] in
                { url in self.endpointLog.values.withLock { $0.append(url.absoluteString) }; return stub }
            }
        }
    }

    var workspace: FluxStore<WorkspaceFeature> { container.workspaceStore() }
    var session: FluxStore<SessionFeature> { container.sessionStore() }
    var settings: FluxStore<SettingsFeature> { container.settingsStore() }
    var settingsModal: ModalRouter<AppRoute> { container.settingsModal() }

    func dispose() async {
        workspace.dispatch(.disconnectRequested())
        for _ in 0..<200 where workspace.state.connection != .disconnected {
            try? await Task.sleep(for: .milliseconds(5))
        }
        await stub.release()
    }

    func wait(_ description: String, sourceLocation: SourceLocation,
              until predicate: @escaping () async -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(4))
        while ContinuousClock.now < deadline {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for \(description)", sourceLocation: sourceLocation)
        throw WorkspaceDriverTimeout()
    }

    struct WorkspaceDriverTimeout: Error {}
}

final class EndpointLog: Sendable {
    let values = Mutex<[String]>([])
}

@MainActor
final class MemoryWorkspaceEndpointSettings: EndpointSettingsService {
    var value: String?
    init(value: String? = nil) { self.value = value }
    func load() -> String? { value }
    func save(_ endpoint: String) throws { value = endpoint }
}

@MainActor
final class WorkspaceProjectsDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }

    /// Connect lists projects without creating a session; the catalogue must have arrived.
    func connect(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        context.workspace.dispatch(.connectRequested(takingControl: true))
        // Succeed with a catalogue, or settle on the failure the caller wants to assert.
        try await context.wait("connection attempt", sourceLocation: sourceLocation) {
            if !self.context.workspace.state.catalogue.projects.isEmpty { return true }
            if case .failed = self.context.workspace.state.connection { return true }
            return false
        }
    }
    func connectWithoutConsent() { context.workspace.dispatch(.connectRequested(takingControl: false)) }
    func connectAgain() { context.workspace.dispatch(.connectRequested(takingControl: true)) }
    func disconnect() async { context.workspace.dispatch(.disconnectRequested()) }
    func back() { context.workspace.dispatch(.back) }
    func newQuickChat() async throws {
        context.workspace.dispatch(.createRequested(projectPath: "/home/pi", title: "New chat"))
        try await tabs.settle()
    }
    func openHistory() async throws {
        context.workspace.dispatch(.openRequested(target: .history("/history/saved"), title: "Saved"))
        try await tabs.settle()
    }
    func openRunningSession() async throws {
        context.workspace.dispatch(.openRequested(target: .runtime("running"), title: "Working"))
        try await tabs.settle()
    }
    /// Create a session inside a known project path, for real-transport acceptance.
    func createSession(projectPath: String, title: String = "New chat",
                       sourceLocation: SourceLocation = #_sourceLocation) async throws {
        context.workspace.dispatch(.createRequested(projectPath: projectPath, title: title))
        try await tabs.settle(sourceLocation: sourceLocation)
    }
    /// Dispatch an open without waiting for it, to assert admission rules.
    func beginOpen(_ target: ProjectSessionTarget = .history("/history/saved"), title: String = "Saved") {
        context.workspace.dispatch(.openRequested(target: target, title: title))
    }
    func openMissingProject(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        context.workspace.dispatch(.createRequested(projectPath: "/missing", title: "Missing"))
        try await context.wait("failed open", sourceLocation: sourceLocation) {
            self.context.workspace.state.error != nil
        }
    }
    func waitForLateProject(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("late project", sourceLocation: sourceLocation) {
            self.context.workspace.state.catalogue.projects.contains { $0.path == "/late" }
        }
    }
    func shouldBeBrowsing(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.isConnected && context.workspace.state.selectedSessionId == nil,
                sourceLocation: sourceLocation)
    }
    func shouldShowSession(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.selectedSession != nil, sourceLocation: sourceLocation)
    }
    func shouldNotShowSession(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.selectedSession == nil, sourceLocation: sourceLocation)
    }
    func shouldShowError(containing text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.error?.contains(text) == true, sourceLocation: sourceLocation)
    }
    func statusShouldBe(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.status == text, sourceLocation: sourceLocation)
    }
    func shouldBeDisconnected(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.connection == .disconnected, sourceLocation: sourceLocation)
    }
    func shouldBeConnecting(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.connection == .connecting, sourceLocation: sourceLocation)
    }
    var tabs: WorkspaceTabsDriver { WorkspaceTabsDriver(context) }
}

/// Open-session tabs: ordering, selection, drafts, reading position and adjacent closure.
/// It never closes or stops a runtime, which the server driver asserts separately.
@MainActor
final class WorkspaceTabsDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }

    /// Opening from a scenario settles the tab, its transcript and its attachment.
    func openQuickChat() async throws {
        context.workspace.dispatch(.createRequested(projectPath: "/home/pi", title: "New chat"))
        try await settle()
    }
    func openHistory() async throws {
        context.workspace.dispatch(.openRequested(target: .history("/history/saved"), title: "Saved"))
        try await settle()
    }
    func openRunningSession() async throws {
        context.workspace.dispatch(.openRequested(target: .runtime("running"), title: "Working"))
        try await settle()
    }

    /// Navigation settles admission, attachment and the visible transcript, so scenarios never
    /// depend on scheduling.
    func settle(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("settled workspace", sourceLocation: sourceLocation) {
            let workspace = self.context.workspace.state
            guard !workspace.isOpening else { return false }
            guard let tab = workspace.selectedSession else {
                return workspace.observedRuntimeId == nil && self.context.session.state.observedSessionId == nil
            }
            return workspace.observedRuntimeId == tab.runtimeId
                && self.context.session.state.observedSessionId == tab.runtimeId
                && self.context.session.state.projection?.session.sessionId == tab.runtimeId
        }
    }
    func select(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        guard let id = tabId(title) else { return }
        context.workspace.dispatch(.selectRequested(id: id))
        try await settle(sourceLocation: sourceLocation)
    }
    /// Begin a switch without waiting for its snapshot, so a late result is testable.
    func beginSelect(_ title: String) {
        guard let id = tabId(title) else { return }
        context.workspace.dispatch(.selectRequested(id: id))
    }
    func close(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        guard let id = tabId(title) else { return }
        context.workspace.dispatch(.closeSession(id))
        try await settle(sourceLocation: sourceLocation)
    }
    func shouldShow(_ titles: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.openSessions.map(\.title) == titles, sourceLocation: sourceLocation)
    }
    func shouldSelect(_ title: String?, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.selectedSession?.title == title, sourceLocation: sourceLocation)
    }
    func shouldHaveNoTabs(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.openSessions.isEmpty, sourceLocation: sourceLocation)
    }
    func enterDraft(_ text: String) { context.workspace.dispatch(.draftChanged(text)) }
    func draftShouldBe(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.workspace.state.draft == text, sourceLocation: sourceLocation)
    }
    func reportReadingPosition(followTail: Bool, anchor: String?) {
        context.workspace.dispatch(.followTailChanged(followTail))
        context.workspace.dispatch(.scrollAnchorChanged(anchor))
    }
    func shouldFollowTail(_ follow: Bool, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.workspace.state.openSessions.first { $0.title == title }
        #expect(tab?.followTail == follow, sourceLocation: sourceLocation)
    }
    func anchorShouldBe(_ anchor: String?, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.workspace.state.openSessions.first { $0.title == title }
        #expect(tab?.scrollAnchor == anchor, sourceLocation: sourceLocation)
    }
    func draftShouldBeRetained(_ text: String, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.workspace.state.openSessions.first { $0.title == title }
        #expect(tab?.draft == text, sourceLocation: sourceLocation)
    }
    func runtimeShouldBe(_ runtimeId: String, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.workspace.state.openSessions.first { $0.title == title }
        #expect(tab?.runtimeId == runtimeId, sourceLocation: sourceLocation)
    }
    func transcriptShouldBe(_ texts: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.projection?.messages.map(\.text) == texts, sourceLocation: sourceLocation)
    }
    func shouldBeGenerating(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.isSending || context.session.state.projection?.status == .running,
                sourceLocation: sourceLocation)
    }
    func observedRuntimeShouldBe(_ runtimeId: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.projection?.session.sessionId == runtimeId, sourceLocation: sourceLocation)
    }
    func waitForObservedRuntime(_ runtimeId: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("observed runtime \(runtimeId)", sourceLocation: sourceLocation) {
            self.context.session.state.projection?.session.sessionId == runtimeId
        }
    }
    func waitForRuntime(_ runtimeId: String, for title: String,
                        sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("runtime \(runtimeId)", sourceLocation: sourceLocation) {
            self.context.workspace.state.openSessions.first { $0.title == title }?.runtimeId == runtimeId
        }
    }
    func waitForSelected(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("selected \(title)", sourceLocation: sourceLocation) {
            self.context.workspace.state.selectedSession?.title == title
        }
    }
    private func tabId(_ title: String) -> String? {
        guard let id = context.workspace.state.openSessions.first(where: { $0.title == title })?.id else {
            Issue.record("No open tab titled \(title)")
            return nil
        }
        return id
    }
}

/// Slice 3: the open-session overview the phone presents as a sheet and Mac as a popover.
/// It reads the container's own mapping, so the rows under test are the rows both shells show.
@MainActor
final class WorkspaceOverviewDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }

    func rows() -> [OpenSessionPresentation] { WorkspaceContainer.openSessions(context.workspace.state) }
    /// Exactly what the overview's new-session action would target.
    var newSessionPath: String? { WorkspaceContainer.newSessionPath(context.workspace.state.catalogue) }

    func shouldShow(_ titles: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rows().map(\.title) == titles, sourceLocation: sourceLocation)
    }
    func shouldShowProjects(_ paths: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rows().map(\.context) == paths, sourceLocation: sourceLocation)
    }
    func shouldSelect(_ title: String?, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rows().first { $0.isSelected }?.title == title, sourceLocation: sourceLocation)
        #expect(rows().filter(\.isSelected).count == (title == nil ? 0 : 1), sourceLocation: sourceLocation)
    }
    func activityShouldBe(_ activity: SessionActivity?, for title: String,
                          sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rows().first { $0.title == title }?.activity == activity, sourceLocation: sourceLocation)
    }
    func shouldBeEmpty(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(rows().isEmpty, sourceLocation: sourceLocation)
    }

    /// Selecting and closing are the same operations the tab strip performs.
    func select(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        guard let id = rows().first(where: { $0.title == title })?.id else {
            Issue.record("No open session titled \(title)", sourceLocation: sourceLocation)
            return
        }
        context.workspace.dispatch(.selectRequested(id: id))
        try await settle(sourceLocation: sourceLocation)
    }
    func close(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        guard let id = rows().first(where: { $0.title == title })?.id else {
            Issue.record("No open session titled \(title)", sourceLocation: sourceLocation)
            return
        }
        context.workspace.dispatch(.closeSession(id))
        try await settle(sourceLocation: sourceLocation)
    }
    /// The same settle the tab strip relies on: attachment and transcript follow the selection.
    func settle(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("overview settled", sourceLocation: sourceLocation) {
            let workspace = self.context.workspace.state
            guard !workspace.isOpening else { return false }
            guard let session = workspace.selectedSession else {
                return workspace.observedRuntimeId == nil
                    && self.context.session.state.observedSessionId == nil
            }
            return workspace.observedRuntimeId == session.runtimeId
                && self.context.session.state.observedSessionId == session.runtimeId
                && self.context.session.state.projection?.session.sessionId == session.runtimeId
        }
    }
    /// The overview's "Projects & history" row: leave the conversation without disconnecting.
    func backToProjects() { context.workspace.dispatch(.back) }
}

@MainActor
final class WorkspaceSettingsDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }
    /// Opening is a router side effect performed by the middleware; wait until it is presented.
    func open(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        context.settings.dispatch(.opened)
        try await context.wait("settings presentation", sourceLocation: sourceLocation) {
            self.context.settingsModal.presentation?.stack.root == .settings
        }
    }
    func enterEndpoint(_ value: String) { context.settings.dispatch(.draftChanged(value)) }
    func save() { context.settings.dispatch(.saveTapped) }
    func cancel() { context.settings.dispatch(.cancelTapped) }
    func shouldBePresented(_ presented: Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("settings presentation == \(presented)", sourceLocation: sourceLocation) {
            (self.context.settingsModal.presentation != nil) == presented
        }
    }
    func shouldShowError(containing text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.settings.state.error?.contains(text) == true, sourceLocation: sourceLocation)
    }
    func draftShouldBe(_ value: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.settings.state.draft == value, sourceLocation: sourceLocation)
    }
    func waitUntilSaved(_ endpoint: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("saved endpoint", sourceLocation: sourceLocation) {
            self.context.settings.state.savedEndpoint == endpoint
        }
    }
    func waitUntilSettled(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("settings settled", sourceLocation: sourceLocation) {
            !self.context.settings.state.isSaving && self.context.settings.state.error != nil
        }
    }
}

/// Fixture controls are distinct from app actions: no test pretends stub events are UI input.
@MainActor
final class WorkspaceServerDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }

    func shouldHaveCreates(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.createCount == count, sourceLocation: sourceLocation)
    }
    func shouldHaveOpens(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.openCount == count, sourceLocation: sourceLocation)
    }
    func shouldHaveAttaches(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.attachedRuntimes.count == count, sourceLocation: sourceLocation)
    }
    func shouldHaveSends(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.sendCount == count, sourceLocation: sourceLocation)
    }
    func shouldHaveStops(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.stopCount == count, sourceLocation: sourceLocation)
    }
    func shouldHaveConnectionCount(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.connectCount == count, sourceLocation: sourceLocation)
    }
    func shouldBeConnected(sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await !context.stub.closed, sourceLocation: sourceLocation)
    }
    func shouldBeDisposed(sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.closed, sourceLocation: sourceLocation)
    }
    func connectionEndpointsShouldBe(_ endpoints: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.endpointLog.values.withLock { $0 } == endpoints, sourceLocation: sourceLocation)
    }
    func waitForStops(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("stop count \(count)", sourceLocation: sourceLocation) { await self.context.stub.stopCount >= count }
    }
    func waitForSends(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("send count \(count)", sourceLocation: sourceLocation) { await self.context.stub.sendCount >= count }
    }
    func waitForDisposal(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("connection disposal", sourceLocation: sourceLocation) { await self.context.stub.closed }
    }
    func waitForDisconnected(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("workspace disconnected", sourceLocation: sourceLocation) {
            self.context.workspace.state.connection == .disconnected
        }
    }
    func createdPathShouldBe(_ path: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.createdPath == path, sourceLocation: sourceLocation)
    }
    func openedHistoryShouldBe(_ path: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.openedHistory == path, sourceLocation: sourceLocation)
    }
    func attachedRuntimeShouldBe(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.attachedRuntimes.last == id, sourceLocation: sourceLocation)
    }
    func rejectConnect(_ message: String) async { await context.stub.setConnectError(.transport(message: message, outcomeUnknown: false)) }
    func rejectOpens() async { await context.stub.setError(.rejected(code: "notFound", message: "Not found")) }
    func loseOpenReceipt() async { await context.stub.setError(.requestExpired(outcomeUnknown: true)) }
    func holdOpen() async { await context.stub.holdOpen() }
    func waitForHeldOpen(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("held open", sourceLocation: sourceLocation) { await self.context.stub.holding }
    }
    func releaseOpen() async { await context.stub.release() }
    func holdAttach() async { await context.stub.holdAttach() }
    func releaseAttach() async { await context.stub.releaseAttach() }
    func waitForHeldAttach(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("held attach", sourceLocation: sourceLocation) { await self.context.stub.heldAttaches > 0 }
    }
    func publishLateCatalogue() async { await context.stub.publishLateCatalogue() }
    /// The server ends a runtime; the app must react through its identity events.
    func closeRuntime(_ sessionId: String) async { await context.stub.closeRuntime(sessionId) }
    func replaceRuntime(_ sessionId: String, with replacement: String) async {
        await context.stub.replaceRuntime(previous: sessionId, current: replacement)
    }
    func publishedRuntimeShouldBe(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.current?.session.sessionId == id, sourceLocation: sourceLocation)
    }
}

fileprivate actor WorkspaceConnectionStub: PiSessionConnection {
    var connectCount = 0
    var createCount = 0
    var openCount = 0
    var sendCount = 0
    var stopCount = 0
    var createdPath: String?
    var openedHistory: String?
    var attachedRuntimes: [String] = []
    var closed = false
    var error: PiError?
    var connectError: PiError?
    var holding = false
    var waiter: CheckedContinuation<Void, Never>?
    var heldAttachCount = 0
    var heldAttaches: Int { heldAttachCount }
    var attachWaiter: CheckedContinuation<Void, Never>?
    var current: DemoSessionProjection?
    var catalogue = PiCatalogue(projects: [.init(path: "/home/pi", name: "Quick Chats", quickChats: true),
                                          .init(path: "/repo", name: "pi-studio", exists: false)],
                                sessions: [.init(sessionId: "running", title: "Working", projectPath: "/repo",
                                                 projectName: "pi-studio", status: "running")])
    private var catalogueObservers: [UUID: AsyncStream<PiCatalogue>.Continuation] = [:]
    private var eventObservers: [UUID: AsyncStream<PiSessionEvent>.Continuation] = [:]
    private var projectionObservers: [UUID: AsyncStream<DemoSessionProjection>.Continuation] = [:]

    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func catalogues() async -> AsyncStream<PiCatalogue> {
        let id = UUID()
        let (stream, listener) = AsyncStream<PiCatalogue>.makeStream(bufferingPolicy: .bufferingNewest(1))
        listener.yield(catalogue)
        catalogueObservers[id] = listener
        listener.onTermination = { [weak self] _ in Task { await self?.removeCatalogue(id) } }
        return stream
    }
    private func removeCatalogue(_ id: UUID) { catalogueObservers.removeValue(forKey: id) }
    private func publishCatalogue() { for observer in catalogueObservers.values { observer.yield(catalogue) } }
    func projections() async -> AsyncStream<DemoSessionProjection> {
        let id = UUID()
        let (stream, listener) = AsyncStream<DemoSessionProjection>.makeStream(bufferingPolicy: .bufferingNewest(1))
        if let current { listener.yield(current) }
        projectionObservers[id] = listener
        listener.onTermination = { [weak self] _ in Task { await self?.removeProjection(id) } }
        return stream
    }
    private func removeProjection(_ id: UUID) { projectionObservers.removeValue(forKey: id) }
    func sessionEvents() async -> AsyncStream<PiSessionEvent> {
        let id = UUID()
        let (stream, listener) = AsyncStream<PiSessionEvent>.makeStream(bufferingPolicy: .bufferingNewest(4))
        eventObservers[id] = listener
        listener.onTermination = { [weak self] _ in Task { await self?.removeEvents(id) } }
        return stream
    }
    private func removeEvents(_ id: UUID) { eventObservers.removeValue(forKey: id) }
    private func publish(_ event: PiSessionEvent) { for observer in eventObservers.values { observer.yield(event) } }

    func connect(takingControl: Bool) async throws {
        connectCount += 1
        guard takingControl else { throw PiError.invalidState }
        if let connectError { throw connectError }
    }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession { throw PiError.invalidState }
    func createSession(projectPath: String) async throws -> DemoSession {
        guard !closed else { throw PiError.disconnected }
        createCount += 1; createdPath = projectPath
        guard projectPath != "/missing" else { throw PiError.rejected(code: "notFound", message: "Project is not available") }
        return select("new-\(createCount)", projectPath)
    }
    func openSession(sessionPath: String) async throws -> DemoSession {
        guard !closed else { throw PiError.disconnected }
        openCount += 1; openedHistory = sessionPath
        if holding { await withCheckedContinuation { waiter = $0 } }
        if let error { throw error }
        return select("saved", "/repo")
    }
    func attachSession(sessionId: String) async throws -> DemoSession {
        guard !closed else { throw PiError.disconnected }
        attachedRuntimes.append(sessionId)
        if heldAttachCount > 0 { heldAttachCount -= 1; await withCheckedContinuation { attachWaiter = $0 } }
        if let error { throw error }
        return select(sessionId, "/repo")
    }
    private func select(_ id: String, _ path: String) -> DemoSession {
        let session = DemoSession(sessionId: id, projectPath: path)
        current = .init(session: session,
                        messages: [.init(id: "answer-\(id)", role: "assistant", text: "Answer from \(id)")],
                        status: id.hasPrefix("running") ? .running : .idle)
        for observer in projectionObservers.values { observer.yield(current!) }
        return session
    }
    func send(_ text: String) async throws { sendCount += 1 }
    func stop() async throws { stopCount += 1 }
    func disconnect() async {
        closed = true
        for observer in catalogueObservers.values { observer.finish() }
        catalogueObservers = [:]
        for observer in eventObservers.values { observer.finish() }
        eventObservers = [:]
        for observer in projectionObservers.values { observer.finish() }
        projectionObservers = [:]
    }
    func setError(_ value: PiError) { error = value }
    func setConnectError(_ value: PiError) { connectError = value }
    func holdOpen() { holding = true }
    func holdAttach() { heldAttachCount += 1 }
    func releaseAttach() { attachWaiter?.resume(); attachWaiter = nil }
    func release() {
        waiter?.resume(); waiter = nil; holding = false
        attachWaiter?.resume(); attachWaiter = nil
    }
    func publishLateCatalogue() {
        catalogue = .init(projects: catalogue.projects + [.init(path: "/late", name: "late")],
                          sessions: catalogue.sessions)
        publishCatalogue()
    }
    func closeRuntime(_ sessionId: String) { publish(.closed(sessionId: sessionId)) }
    func replaceRuntime(previous: String, current replacement: String) {
        _ = select(replacement, "/repo")
        catalogue = .init(projects: catalogue.projects,
                          sessions: catalogue.sessions.map {
                              $0.sessionId == previous
                                  ? .init(sessionId: replacement, title: $0.title, sessionPath: $0.sessionPath,
                                          projectPath: $0.projectPath, projectName: $0.projectName, status: $0.status)
                                  : $0
                          })
        publishCatalogue()
        publish(.replaced(previous: DemoSession(sessionId: previous, projectPath: "/repo"),
                          current: DemoSession(sessionId: replacement, projectPath: "/repo")))
    }
}

/// Conversation gestures on the selected tab, for scenarios that also navigate.
@MainActor
final class WorkspaceConversationDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }

    var state: SessionFeature.State { context.session.state }
    func sendPrompt(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        context.session.dispatch(.sendRequested(text: text))
        try await context.wait("admitted send", sourceLocation: sourceLocation) { !self.context.session.state.isSending }
        #expect(context.session.state.errorMessage == nil, sourceLocation: sourceLocation)
    }
    func stop() { context.session.dispatch(.stopRequested()) }
    func waitUntilReady(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait("idle conversation", sourceLocation: sourceLocation) { self.context.session.state.canEditMessage }
    }
    func shouldShowError(containing text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.errorMessage?.contains(text) == true, sourceLocation: sourceLocation)
    }
    func clearInstructionShouldBe(_ text: String?, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.clearDraftMatching == text, sourceLocation: sourceLocation)
    }
    func messagesShouldBe(_ texts: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.projection?.messages.map(\.text) == texts, sourceLocation: sourceLocation)
    }
    func shouldHaveMessageCount(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.projection?.messages.count == count, sourceLocation: sourceLocation)
    }
    func waitForPartialReply(messageCount: Int, sourceLocation: SourceLocation = #_sourceLocation) async throws -> String {
        try await context.wait("partial reply \(messageCount)", sourceLocation: sourceLocation) {
            let state = self.context.session.state
            return state.canStop && state.projection?.messages.count == messageCount
                && state.projection?.messages.last?.role == "assistant"
                && state.projection?.messages.last?.isPartial == true
                && state.projection?.messages.last?.text.isEmpty == false
        }
        return context.session.state.projection!.messages.last!.text
    }
    func captureLastReply(sourceLocation: SourceLocation = #_sourceLocation) throws -> String {
        let text = try #require(context.session.state.projection?.messages.last?.text, sourceLocation: sourceLocation)
        try #require(!text.isEmpty, sourceLocation: sourceLocation)
        return text
    }
    func lastReplyShouldDiffer(from partial: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.projection?.messages.last?.text != partial, sourceLocation: sourceLocation)
    }
    func captureTranscript() -> [DemoMessage] { context.session.state.projection?.messages ?? [] }
    func transcriptShouldBe(_ messages: [DemoMessage], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.projection?.messages == messages, sourceLocation: sourceLocation)
    }
    func shouldBeDisconnected(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.connection == .disconnected, sourceLocation: sourceLocation)
    }
}
