import SwiftUI
import Testing
import ViewInspector
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

    private func sidebar(_ presentation: WorkspacePresentation,
                         open: @escaping @MainActor (ProjectSessionTarget, String) -> Void = { _, _ in },
                         create: @escaping @MainActor (String) -> Void = { _ in },
                         later: @escaping @MainActor (String) -> Void = { _ in },
                         archive: @escaping @MainActor (String) -> Void = { _ in },
                         connection: @escaping @MainActor () -> Void = {},
                         settings: @escaping @MainActor () -> Void = {}) -> WorkspaceSidebar {
        WorkspaceSidebar(presentation: presentation, onOpen: open, onCreate: create,
                         onMoveToLater: later, onArchive: archive, onConnection: connection,
                         onSettings: settings)
    }

    @Test func showsNonemptySectionsAndInitiallyCollapsedLater() throws {
        var presentation = WorkspacePresentation()
        presentation.inboxSessions = [session("blocked", status: .needsYou),
                                      session("ready", status: .ready, path: "/ready"),
                                      session("running", status: .running),
                                      session("parked", status: .later, path: "/parked")]
        let view = try sidebar(presentation).inspect()

        #expect(try view.find(text: "Needs you").string() == "Needs you")
        #expect(try view.find(text: "Ready").string() == "Ready")
        #expect(try view.find(viewWithAccessibilityIdentifier: "inbox-running").button().isDisabled())
        #expect(throws: (any Error).self) { try view.find(viewWithAccessibilityIdentifier: "inbox-parked") }
        #expect(try view.find(viewWithAccessibilityIdentifier: "inboxToggle-later").button().labelView().find(text: "1").string() == "1")
    }

    @Test func emptySectionsAreAbsentAndErrorsAreDisplayed() throws {
        var presentation = WorkspacePresentation()
        presentation.error = "Connection failed"
        let view = try sidebar(presentation).inspect()

        #expect(try view.find(viewWithAccessibilityIdentifier: "errorMessage").text().string() == "Connection failed")
        #expect(throws: (any Error).self) { try view.find(text: "Needs you") }
        #expect(throws: (any Error).self) { try view.find(viewWithAccessibilityIdentifier: "inboxToggle-running") }
        #expect(throws: (any Error).self) { try view.find(viewWithAccessibilityIdentifier: "inboxToggle-later") }
    }

    @Test func openAndSavedSessionActionsForwardTheirIdentity() throws {
        var presentation = WorkspacePresentation()
        presentation.canOpen = true
        presentation.inboxSessions = [session("ready", status: .ready, path: "/ready")]
        var opened: (ProjectSessionTarget, String)?
        var moved: String?
        var archived: String?
        let view = try sidebar(presentation, open: { opened = ($0, $1) },
                               later: { moved = $0 }, archive: { archived = $0 }).inspect()

        try view.find(viewWithAccessibilityIdentifier: "inbox-ready").button().tap()
        try view.find(viewWithAccessibilityIdentifier: "moveLater-ready").button().tap()
        try view.find(viewWithAccessibilityIdentifier: "archive-ready").button().tap()

        #expect(opened?.0 == .history("/ready"))
        #expect(opened?.1 == "Title ready")
        #expect(moved == "/ready")
        #expect(archived == "/ready")
    }

    @Test func creationAndFooterActionsForwardCallbacks() throws {
        var presentation = WorkspacePresentation()
        presentation.canOpen = true
        presentation.newSessionPath = "/repo"
        presentation.status = "Connected"
        presentation.canConnect = false
        var created: String?
        var connections = 0
        var settings = 0
        let view = try sidebar(presentation, create: { created = $0 },
                               connection: { connections += 1 }, settings: { settings += 1 }).inspect()

        try view.find(viewWithAccessibilityIdentifier: "newInboxSession").button().tap()
        try view.find(viewWithAccessibilityIdentifier: "connectButton").button().tap()
        try view.find(viewWithAccessibilityIdentifier: "settingsButton").button().tap()

        #expect(created == "/repo")
        #expect(connections == 1)
        #expect(settings == 1)
        #expect(try view.find(viewWithAccessibilityIdentifier: "connectionStatus").text().string() == "Connected")
    }

    @Test func creationAndOpeningRespectAvailability() throws {
        var presentation = WorkspacePresentation()
        presentation.canOpen = true
        presentation.inboxSessions = [session("closed", status: .ready, canOpen: false)]
        let view = try sidebar(presentation).inspect()

        #expect(try view.find(viewWithAccessibilityIdentifier: "newInboxSession").button().isDisabled())
        #expect(try view.find(viewWithAccessibilityIdentifier: "inbox-closed").button().isDisabled())
        #expect(throws: (any Error).self) { try view.find(viewWithAccessibilityIdentifier: "moveLater-closed") }
        #expect(throws: (any Error).self) { try view.find(viewWithAccessibilityIdentifier: "archive-closed") }
    }
}
