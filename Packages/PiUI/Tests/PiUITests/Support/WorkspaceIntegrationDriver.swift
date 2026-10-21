import Foundation
import PiSDK
import Testing
import PiUI

@MainActor final class WorkspaceIntegrationDriver {
    let projects: WorkspaceProjectsDriver
    let tabs: WorkspaceTabsDriver
    let chat: WorkspaceChatDriver
    let server: WorkspaceServerDriver
    private let context: WorkspaceContext
    private init() {
        let context = WorkspaceContext()
        self.context = context
        projects = WorkspaceProjectsDriver(context)
        tabs = WorkspaceTabsDriver(context)
        chat = WorkspaceChatDriver(context)
        server = WorkspaceServerDriver(context)
    }
    static func run(_ scenario: (WorkspaceIntegrationDriver) async throws -> Void) async throws {
        let app = WorkspaceIntegrationDriver()
        do { try await scenario(app); await app.context.dispose() }
        catch { await app.context.dispose(); throw error }
    }
}
@MainActor fileprivate final class WorkspaceContext {
    let stub = WorkspaceConnectionStub()
    let session = SessionController()
    lazy var controller = WorkspaceController(session: session, makeConnection: { [stub] _ in stub })
    var opening: Task<Void, Never>?
    var selecting: Task<Void, Never>?
    func dispose() async { await controller.disconnect(); await stub.release(); await opening?.value; await selecting?.value }
    func wait(_ predicate: () async -> Bool, sourceLocation: SourceLocation) async throws {
        for _ in 0..<400 { if await predicate() { return }; try await Task.sleep(for: .milliseconds(5)) }
        Issue.record("Workspace condition timed out", sourceLocation: sourceLocation)
        throw PiError.requestExpired(outcomeUnknown: false)
    }
}
@MainActor final class WorkspaceProjectsDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }
    /// Connect lists projects without creating a session; fixtures wait for the
    /// catalogue so a scenario never depends on stream scheduling.
    func connect(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        await context.controller.connect(takingControl: true)
        try await context.wait({ !self.context.controller.state.catalogue.projects.isEmpty }, sourceLocation: sourceLocation)
    }
    func disconnect() async { await context.controller.disconnect() }
    func back() { context.controller.back() }
    func newQuickChat() async { await context.controller.createSession(projectPath: "/home/pi") }
    func openHistory() async { await context.controller.open(.history("/history/saved"), title: "Saved") }
    func openRunningSession() async { await context.controller.open(.runtime("running"), title: "Working") }
    func beginOpen(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        context.opening = Task { await self.openHistory() }
        try await context.wait({ await self.context.stub.openCount > 0 }, sourceLocation: sourceLocation)
    }
    func finishOpen() async { await context.opening?.value; context.opening = nil }
    func shouldBeBrowsing(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.isConnected && context.controller.state.selectedSessionId == nil, sourceLocation: sourceLocation)
    }
    func shouldShowSession(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.selectedSession != nil, sourceLocation: sourceLocation)
    }
    func shouldNotShowSession(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.selectedSession == nil, sourceLocation: sourceLocation)
    }
    func shouldShowError(containing text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.error?.contains(text) == true, sourceLocation: sourceLocation)
    }
    func waitForLateProject(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait({ self.context.controller.state.catalogue.projects.contains { $0.path == "/late" } }, sourceLocation: sourceLocation)
    }
}
/// Open-session tabs: ordering, selection, drafts and adjacent closure. It never
/// closes or stops a runtime, which the server driver asserts separately.
@MainActor final class WorkspaceTabsDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }

    // Every navigation settles the visible transcript, so scenarios never depend on
    // stream scheduling. Selection work itself stays asynchronous in the workspace.
    func openQuickChat() async throws {
        await context.controller.createSession(projectPath: "/home/pi"); try await settle()
    }
    func openHistory() async throws {
        await context.controller.open(.history("/history/saved"), title: "Saved"); try await settle()
    }
    func openRunningSession() async throws {
        await context.controller.open(.runtime("running"), title: "Working"); try await settle()
    }
    private func settle(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        guard let tab = context.controller.state.selectedSession else { return }
        try await context.wait({
            let state = self.context.session.state
            return state.projection?.session.sessionId == tab.runtimeId && state.draft == tab.draft
        }, sourceLocation: sourceLocation)
    }
    /// Selecting a tab is a local workspace action; the workspace attaches to it.
    func select(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        guard let id = tabId(title) else { return }
        await context.controller.selectSession(id: id)
        try await settle(sourceLocation: sourceLocation)
    }
    /// Begin a switch without waiting for its snapshot, to test late results.
    func beginSelect(_ title: String) {
        guard let id = tabId(title) else { return }
        context.selecting = Task { await context.controller.selectSession(id: id) }
    }
    func finishSelecting() async { await context.selecting?.value; context.selecting = nil }
    private func tabId(_ title: String) -> String? {
        guard let id = context.controller.state.openSessions.first(where: { $0.title == title })?.id else {
            Issue.record("No open tab titled \(title)"); return nil
        }
        return id
    }
    func close(_ title: String) async {
        guard let id = context.controller.state.openSessions.first(where: { $0.title == title })?.id else {
            Issue.record("No open tab titled \(title)"); return
        }
        await context.controller.closeSession(id: id)
    }
    func shouldShow(_ titles: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.openSessions.map(\.title) == titles, sourceLocation: sourceLocation)
    }
    func shouldSelect(_ title: String?, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.selectedSession?.title == title, sourceLocation: sourceLocation)
    }
    func shouldHaveNoTabs(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.openSessions.isEmpty, sourceLocation: sourceLocation)
    }
    /// What the transcript reports when the user reads older content.
    func reportReadingPosition(followTail: Bool, anchor: String?) {
        context.controller.setFollowTail(followTail)
        context.controller.setScrollAnchor(anchor)
    }
    func shouldFollowTail(_ follow: Bool, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.controller.state.openSessions.first { $0.title == title }
        #expect(tab?.followTail == follow, sourceLocation: sourceLocation)
    }
    func anchorShouldBe(_ anchor: String?, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.controller.state.openSessions.first { $0.title == title }
        #expect(tab?.scrollAnchor == anchor, sourceLocation: sourceLocation)
    }
    func enterDraft(_ text: String) { context.controller.setDraft(text) }
    func draftShouldBe(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.draft == text, sourceLocation: sourceLocation)
    }
    func runtimeShouldBe(_ runtimeId: String, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.controller.state.openSessions.first { $0.title == title }
        #expect(tab?.runtimeId == runtimeId, sourceLocation: sourceLocation)
    }
    func draftShouldBeRetained(_ text: String, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.controller.state.openSessions.first { $0.title == title }
        #expect(tab?.draft == text, sourceLocation: sourceLocation)
    }
    func waitForObservedRuntime(_ runtimeId: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait({ self.context.session.state.projection?.session.sessionId == runtimeId },
                              sourceLocation: sourceLocation)
    }
    func waitForSelected(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait({ self.context.controller.state.selectedSession?.title == title }, sourceLocation: sourceLocation)
    }
    func waitForRuntime(_ runtimeId: String, for title: String,
                        sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait({
            self.context.controller.state.openSessions.first { $0.title == title }?.runtimeId == runtimeId
        }, sourceLocation: sourceLocation)
    }
    func observedRuntimeShouldBe(_ runtimeId: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.projection?.session.sessionId == runtimeId, sourceLocation: sourceLocation)
    }
    func transcriptShouldBe(_ texts: [String], sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.projection?.messages.map(\.text) == texts, sourceLocation: sourceLocation)
    }
    func shouldBeGenerating(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.isSending || context.session.state.projection?.status == .running,
                sourceLocation: sourceLocation)
    }
}

@MainActor final class WorkspaceChatDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }
    /// What the transcript reports when the user reads older content.
    func reportReadingPosition(followTail: Bool, anchor: String?) {
        context.controller.setFollowTail(followTail)
        context.controller.setScrollAnchor(anchor)
    }
    func shouldFollowTail(_ follow: Bool, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.controller.state.openSessions.first { $0.title == title }
        #expect(tab?.followTail == follow, sourceLocation: sourceLocation)
    }
    func anchorShouldBe(_ anchor: String?, for title: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let tab = context.controller.state.openSessions.first { $0.title == title }
        #expect(tab?.scrollAnchor == anchor, sourceLocation: sourceLocation)
    }
    func enterDraft(_ text: String) { context.controller.setDraft(text) }
    func draftShouldBe(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.draft == text, sourceLocation: sourceLocation)
    }
}
@MainActor final class WorkspaceServerDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }
    func shouldHaveCreates(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.createCount == count, sourceLocation: sourceLocation) }
    func shouldHaveOpens(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.openCount == count, sourceLocation: sourceLocation) }
    func shouldHaveAttaches(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.attachedRuntimes.count == count, sourceLocation: sourceLocation) }
    func shouldHaveSends(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.sendCount == count, sourceLocation: sourceLocation) }
    func shouldHaveStops(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.stopCount == count, sourceLocation: sourceLocation) }
    func lastAttachedRuntimeShouldBe(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.attachedRuntimes.last == id, sourceLocation: sourceLocation)
    }
    func holdAttach() async { await context.stub.holdAttach() }
    func releaseAttach() async { await context.stub.releaseAttach() }
    func waitForHeldAttach(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait({ await self.context.stub.heldAttaches > 0 }, sourceLocation: sourceLocation)
    }
    /// The server ends a runtime; the app must react through its identity events.
    func closeRuntime(_ sessionId: String) async { await context.stub.closeRuntime(sessionId) }
    func replaceRuntime(_ sessionId: String, with replacement: String) async {
        await context.stub.replaceRuntime(previous: sessionId, current: replacement)
    }
    func publishedRuntimeShouldBe(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) async {
        #expect(await context.stub.current?.session.sessionId == id, sourceLocation: sourceLocation)
    }
    func createdPathShouldBe(_ path: String, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.createdPath == path, sourceLocation: sourceLocation) }
    func openedHistoryShouldBe(_ path: String, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.openedHistory == path, sourceLocation: sourceLocation) }
    func attachedRuntimeShouldBe(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.attachedRuntime == id, sourceLocation: sourceLocation) }
    func shouldBeConnected(sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await !context.stub.closed, sourceLocation: sourceLocation) }
    func rejectOpens() async { await context.stub.setError(.rejected(code: "notFound", message: "Not found")) }
    func loseOpenReceipt() async { await context.stub.setError(.requestExpired(outcomeUnknown: true)) }
    func holdOpen() async { await context.stub.holdOpen() }
    func releaseOpen() async { await context.stub.release() }
    func publishLateCatalogue() async { await context.stub.publishLateCatalogue() }
}
fileprivate actor WorkspaceConnectionStub: PiSessionConnection {
    var createCount = 0
    var openCount = 0
    var createdPath: String?
    var openedHistory: String?
    var attachedRuntime: String?
    var attachedRuntimes: [String] = []
    var sendCount = 0
    var stopCount = 0
    var closed = false
    var error: PiError?
    var holding = false
    var waiter: CheckedContinuation<Void, Never>?
    var current: DemoSessionProjection?
    var catalogue = PiCatalogue(projects: [.init(path: "/home/pi", name: "Quick Chats", quickChats: true)])
    let (catalogueStream, updates) = AsyncStream<PiCatalogue>.makeStream(bufferingPolicy: .bufferingNewest(1))
    func states() async -> AsyncStream<PiConnectionState> { AsyncStream { $0.finish() } }
    func projections() async -> AsyncStream<DemoSessionProjection> { let value = current; return AsyncStream { if let value { $0.yield(value) }; $0.finish() } }
    func catalogues() async -> AsyncStream<PiCatalogue> { updates.yield(catalogue); return catalogueStream }
    private var eventObservers: [UUID: AsyncStream<PiSessionEvent>.Continuation] = [:]
    func sessionEvents() async -> AsyncStream<PiSessionEvent> {
        let id = UUID()
        let (stream, listener) = AsyncStream<PiSessionEvent>.makeStream(bufferingPolicy: .bufferingNewest(4))
        eventObservers[id] = listener
        listener.onTermination = { [weak self] _ in Task { await self?.removeEvents(id) } }
        return stream
    }
    private func removeEvents(_ id: UUID) { eventObservers.removeValue(forKey: id) }
    /// Fixture controls: the server, not the app, decides that a runtime ended or moved.
    func closeRuntime(_ sessionId: String) { publish(.closed(sessionId: sessionId)) }
    func replaceRuntime(previous: String, current replacement: String) {
        // The replacement carries the work forward, so the projected runtime is the new one.
        _ = select(replacement, "/repo")
        publish(.replaced(previous: DemoSession(sessionId: previous, projectPath: "/repo"),
                          current: DemoSession(sessionId: replacement, projectPath: "/repo")))
    }
    private func publish(_ event: PiSessionEvent) { for observer in eventObservers.values { observer.yield(event) } }
    func connect(takingControl: Bool) async throws { guard takingControl else { throw PiError.invalidState } }
    func connectDemo(projectPath: String, takingControl: Bool) async throws -> DemoSession { throw PiError.invalidState }
    func createSession(projectPath: String) async throws -> DemoSession {
        createCount += 1; createdPath = projectPath
        return select("new-\(createCount)", projectPath)
    }
    func openSession(sessionPath: String) async throws -> DemoSession {
        openCount += 1; openedHistory = sessionPath
        if holding { await withCheckedContinuation { waiter = $0 } }
        if let error { throw error }
        return select("saved", "/repo")
    }
    func attachSession(sessionId: String) async throws -> DemoSession {
        attachedRuntime = sessionId; attachedRuntimes.append(sessionId)
        if heldAttachCount > 0 { heldAttachCount -= 1; await withCheckedContinuation { attachWaiter = $0 } }
        return select(sessionId, "/repo")
    }
    private func select(_ id: String, _ path: String) -> DemoSession {
        let session = DemoSession(sessionId: id, projectPath: path)
        current = .init(session: session, messages: [.init(id: "answer-\(id)", role: "assistant", text: "Answer from \(id)")],
                        // `running*` fixtures are busy; a replacement keeps running.
                        status: id.hasPrefix("running") ? .running : .idle)
        return session
    }
    func send(_ text: String) async throws { sendCount += 1 }
    func stop() async throws { stopCount += 1 }
    func disconnect() async { closed = true; updates.finish(); for observer in eventObservers.values { observer.finish() }; eventObservers = [:] }
    func setError(_ value: PiError) { error = value }
    func holdOpen() { holding = true }
    /// The next `attach` waits until the test releases it, so a late result is testable.
    var heldAttachCount = 0
    var heldAttaches: Int { heldAttachCount }
    var attachWaiter: CheckedContinuation<Void, Never>?
    func holdAttach() { heldAttachCount += 1 }
    func releaseAttach() { attachWaiter?.resume(); attachWaiter = nil }
    func release() { waiter?.resume(); waiter = nil; holding = false }
    func publishLateCatalogue() {
        catalogue = .init(projects: catalogue.projects + [.init(path: "/late", name: "late")])
        updates.yield(catalogue)
    }
}
