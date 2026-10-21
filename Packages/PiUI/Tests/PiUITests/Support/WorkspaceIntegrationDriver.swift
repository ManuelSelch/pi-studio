import Foundation
import PiSDK
import Testing
import PiUI

@MainActor final class WorkspaceIntegrationDriver {
    let projects: WorkspaceProjectsDriver
    let chat: WorkspaceChatDriver
    let server: WorkspaceServerDriver
    private let context: WorkspaceContext
    private init() {
        let context = WorkspaceContext()
        self.context = context
        projects = WorkspaceProjectsDriver(context)
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
    lazy var controller = ProjectsController(session: session, makeConnection: { [stub] _ in stub })
    var opening: Task<Void, Never>?
    func dispose() async { await controller.disconnect(); await stub.release(); await opening?.value }
    func wait(_ predicate: () async -> Bool, sourceLocation: SourceLocation) async throws {
        for _ in 0..<400 { if await predicate() { return }; try await Task.sleep(for: .milliseconds(5)) }
        Issue.record("Workspace condition timed out", sourceLocation: sourceLocation)
        throw PiError.requestExpired(outcomeUnknown: false)
    }
}
@MainActor final class WorkspaceProjectsDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }
    func connect() async { await context.controller.connect(takingControl: true) }
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
        #expect(context.controller.state.isConnected && context.controller.state.selected == nil, sourceLocation: sourceLocation)
    }
    func shouldShowSession(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.selected != nil, sourceLocation: sourceLocation)
    }
    func shouldNotShowSession(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.selected == nil, sourceLocation: sourceLocation)
    }
    func shouldShowError(containing text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.controller.state.error?.contains(text) == true, sourceLocation: sourceLocation)
    }
    func waitForLateProject(sourceLocation: SourceLocation = #_sourceLocation) async throws {
        try await context.wait({ self.context.controller.state.catalogue.projects.contains { $0.path == "/late" } }, sourceLocation: sourceLocation)
    }
}
@MainActor final class WorkspaceChatDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }
    func enterDraft(_ text: String) { context.session.setDraft(text) }
    func draftShouldBe(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(context.session.state.draft == text, sourceLocation: sourceLocation)
    }
}
@MainActor final class WorkspaceServerDriver {
    private let context: WorkspaceContext
    fileprivate init(_ context: WorkspaceContext) { self.context = context }
    func shouldHaveCreates(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.createCount == count, sourceLocation: sourceLocation) }
    func shouldHaveOpens(_ count: Int, sourceLocation: SourceLocation = #_sourceLocation) async { #expect(await context.stub.openCount == count, sourceLocation: sourceLocation) }
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
    func attachSession(sessionId: String) async throws -> DemoSession { attachedRuntime = sessionId; return select(sessionId, "/repo") }
    private func select(_ id: String, _ path: String) -> DemoSession {
        let session = DemoSession(sessionId: id, projectPath: path); current = .init(session: session); return session
    }
    func send(_ text: String) async throws {}
    func stop() async throws {}
    func disconnect() async { closed = true; updates.finish() }
    func setError(_ value: PiError) { error = value }
    func holdOpen() { holding = true }
    func release() { waiter?.resume(); waiter = nil; holding = false }
    func publishLateCatalogue() {
        catalogue = .init(projects: catalogue.projects + [.init(path: "/late", name: "late")])
        updates.yield(catalogue)
    }
}
