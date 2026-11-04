import SwiftUI
import ViewInspector
@testable import PiUI

/// Drives the real sidebar with value inputs and records its outgoing callbacks.
@MainActor
final class WorkspaceSidebarDriver {
    private let presentation: WorkspacePresentation
    private(set) var openedTarget: ProjectSessionTarget?
    private(set) var openedTitle: String?
    private(set) var createdPath: String?
    private(set) var movedPath: String?
    private(set) var archivedPath: String?
    private(set) var connectionRequests = 0
    private(set) var settingsRequests = 0

    init(_ presentation: WorkspacePresentation) {
        self.presentation = presentation
    }

    private var sidebar: WorkspaceSidebar {
        WorkspaceSidebar(presentation: presentation,
                         onOpen: { [unowned self] target, title in
                             openedTarget = target; openedTitle = title
                         },
                         onCreate: { [unowned self] in createdPath = $0 },
                         onMoveToLater: { [unowned self] in movedPath = $0 },
                         onArchive: { [unowned self] in archivedPath = $0 },
                         onConnection: { [unowned self] in connectionRequests += 1 },
                         onSettings: { [unowned self] in settingsRequests += 1 })
    }

    func showsSection(_ title: String) throws -> Bool {
        let view = try sidebar.inspect()
        return (try? view.find(text: title).string()) == title
    }

    func showsDisclosure(_ section: String) throws -> Bool {
        try hasElement("inboxToggle-\(section.lowercased())")
    }

    func disclosureCount(_ section: String, expected: String) throws -> String {
        try sidebar.inspect().find(viewWithAccessibilityIdentifier: "inboxToggle-\(section.lowercased())")
            .button().labelView().find(text: expected).string()
    }

    func showsSession(_ id: String) throws -> Bool { try hasElement("inbox-\(id)") }
    func showsMoveToLater(_ id: String) throws -> Bool { try hasElement("moveLater-\(id)") }
    func showsArchive(_ id: String) throws -> Bool { try hasElement("archive-\(id)") }

    func sessionIsDisabled(_ id: String) throws -> Bool {
        try sidebar.inspect().find(viewWithAccessibilityIdentifier: "inbox-\(id)").button().isDisabled()
    }

    func creationIsDisabled() throws -> Bool {
        try sidebar.inspect().find(viewWithAccessibilityIdentifier: "newInboxSession").button().isDisabled()
    }

    func errorMessage() throws -> String {
        try sidebar.inspect().find(viewWithAccessibilityIdentifier: "errorMessage").text().string()
    }

    func connectionStatus() throws -> String {
        try sidebar.inspect().find(viewWithAccessibilityIdentifier: "connectionStatus").text().string()
    }

    func openSession(_ id: String) throws { try tap("inbox-\(id)") }
    func moveToLater(_ id: String) throws { try tap("moveLater-\(id)") }
    func archive(_ id: String) throws { try tap("archive-\(id)") }
    func createSession() throws { try tap("newInboxSession") }
    func changeConnection() throws { try tap("connectButton") }
    func openSettings() throws { try tap("settingsButton") }

    private func hasElement(_ identifier: String) throws -> Bool {
        let view = try sidebar.inspect()
        return (try? view.find(viewWithAccessibilityIdentifier: identifier)) != nil
    }

    private func tap(_ identifier: String) throws {
        try sidebar.inspect().find(viewWithAccessibilityIdentifier: identifier).button().tap()
    }
}
