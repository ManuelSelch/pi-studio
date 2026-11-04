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

        try sidebar.sectionShouldBeVisible("Needs you")
        try sidebar.sectionShouldBeVisible("Ready")
        try sidebar.sessionShouldBeDisabled("running")
        try sidebar.sessionShouldBeAbsent("parked")
        try sidebar.disclosureShouldShowCount("1", for: "Later")
    }

    @Test func emptySectionsAreAbsentAndErrorsAreDisplayed() throws {
        var presentation = WorkspacePresentation()
        presentation.error = "Connection failed"
        let sidebar = WorkspaceSidebarDriver(presentation)

        try sidebar.errorShouldBe("Connection failed")
        try sidebar.sectionShouldBeAbsent("Needs you")
        try sidebar.disclosureShouldBeAbsent("Running")
        try sidebar.disclosureShouldBeAbsent("Later")
    }

    @Test func openAndSavedSessionActionsForwardTheirIdentity() throws {
        var presentation = WorkspacePresentation()
        presentation.canOpen = true
        presentation.inboxSessions = [session("ready", status: .ready, path: "/ready")]
        let sidebar = WorkspaceSidebarDriver(presentation)

        try sidebar.openSession("ready")
        try sidebar.moveToLater("ready")
        try sidebar.archive("ready")

        sidebar.openShouldHaveBeenRequested(.history("/ready"), title: "Title ready")
        sidebar.moveToLaterShouldHaveBeenRequested("/ready")
        sidebar.archiveShouldHaveBeenRequested("/ready")
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

        sidebar.creationShouldHaveBeenRequested("/repo")
        sidebar.connectionShouldHaveBeenRequestedOnce()
        sidebar.settingsShouldHaveBeenRequestedOnce()
        try sidebar.connectionStatusShouldBe("Connected")
    }

    @Test func creationAndOpeningRespectAvailability() throws {
        var presentation = WorkspacePresentation()
        presentation.canOpen = true
        presentation.inboxSessions = [session("closed", status: .ready, canOpen: false)]
        let sidebar = WorkspaceSidebarDriver(presentation)

        try sidebar.creationShouldBeDisabled()
        try sidebar.sessionShouldBeDisabled("closed")
        try sidebar.moveToLaterShouldBeAbsent("closed")
        try sidebar.archiveShouldBeAbsent("closed")
    }
}
