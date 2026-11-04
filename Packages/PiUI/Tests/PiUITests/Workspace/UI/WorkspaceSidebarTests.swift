import Testing
@testable import PiUI

@MainActor
struct WorkspaceSidebarTests {
    private func session(_ id: String, status: InboxSession.Status, path: String? = nil,
                         canOpen: Bool = true) -> InboxSession {
        let row = ProjectSessionRow(id: id, title: "Title \(id)", detail: nil, checkoutPath: "/repo",
                                    activity: nil, target: .history(path ?? id), canOpen: canOpen,
                                    runtimeId: nil, sessionPath: path)
        return InboxSession(row: row, status: status, displayLines: ["Project", "Title \(id)"])
    }

    @Test func showsNonemptySectionsAndInitiallyCollapsedLater() throws {
        var presentation = WorkspacePresentation()
        presentation.inboxSessions = [session("blocked", status: .needsYou),
                                      session("ready", status: .ready, path: "/ready"),
                                      session("running", status: .running),
                                      session("parked", status: .later, path: "/parked")]
        let sidebar = WorkspaceSidebarDriver(presentation)

        #expect(try sidebar.showsSection("Needs you"))
        #expect(try sidebar.showsSection("Ready"))
        #expect(try sidebar.sessionIsDisabled("running"))
        #expect(try !sidebar.showsSession("parked"))
        #expect(try sidebar.disclosureCount("Later", expected: "1") == "1")
    }

    @Test func emptySectionsAreAbsentAndErrorsAreDisplayed() throws {
        var presentation = WorkspacePresentation()
        presentation.error = "Connection failed"
        let sidebar = WorkspaceSidebarDriver(presentation)

        #expect(try sidebar.errorMessage() == "Connection failed")
        #expect(try !sidebar.showsSection("Needs you"))
        #expect(try !sidebar.showsDisclosure("Running"))
        #expect(try !sidebar.showsDisclosure("Later"))
    }

    @Test func openAndSavedSessionActionsForwardTheirIdentity() throws {
        var presentation = WorkspacePresentation()
        presentation.canOpen = true
        presentation.inboxSessions = [session("ready", status: .ready, path: "/ready")]
        let sidebar = WorkspaceSidebarDriver(presentation)

        try sidebar.openSession("ready")
        try sidebar.moveToLater("ready")
        try sidebar.archive("ready")

        #expect(sidebar.openedTarget == .history("/ready"))
        #expect(sidebar.openedTitle == "Title ready")
        #expect(sidebar.movedPath == "/ready")
        #expect(sidebar.archivedPath == "/ready")
    }

    @Test func creationAndFooterActionsForwardCallbacks() throws {
        var presentation = WorkspacePresentation()
        presentation.canOpen = true
        presentation.newSessionPath = "/repo"
        presentation.status = "Connected"
        presentation.canConnect = false
        let sidebar = WorkspaceSidebarDriver(presentation)

        try sidebar.createSession()
        try sidebar.changeConnection()
        try sidebar.openSettings()

        #expect(sidebar.createdPath == "/repo")
        #expect(sidebar.connectionRequests == 1)
        #expect(sidebar.settingsRequests == 1)
        #expect(try sidebar.connectionStatus() == "Connected")
    }

    @Test func creationAndOpeningRespectAvailability() throws {
        var presentation = WorkspacePresentation()
        presentation.canOpen = true
        presentation.inboxSessions = [session("closed", status: .ready, canOpen: false)]
        let sidebar = WorkspaceSidebarDriver(presentation)

        #expect(try sidebar.creationIsDisabled())
        #expect(try sidebar.sessionIsDisabled("closed"))
        #expect(try !sidebar.showsMoveToLater("closed"))
        #expect(try !sidebar.showsArchive("closed"))
    }
}
