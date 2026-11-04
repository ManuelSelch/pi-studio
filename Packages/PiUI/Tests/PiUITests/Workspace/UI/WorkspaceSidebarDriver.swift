import SwiftUI
import Testing
import ViewInspector
@testable import PiUI

/// Drives the real sidebar with value inputs and records its outgoing callbacks.
@MainActor
final class WorkspaceSidebarDriver {
    private let presentation: WorkspacePresentation
    private var openedTarget: ProjectSessionTarget?
    private var openedTitle: String?
    private var createdPath: String?
    private var movedPath: String?
    private var archivedPath: String?
    private var connectionRequests = 0
    private var settingsRequests = 0

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

    func sectionShouldBeVisible(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let view = try sidebar.inspect()
        let text = try view.find(text: title).string()
        #expect(text == title, "Section \(title) should be visible", sourceLocation: sourceLocation)
    }

    func sectionShouldBeAbsent(_ title: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let view = try sidebar.inspect()
        let found = (try? view.find(text: title)) != nil
        #expect(!found, "Section \(title) should be absent", sourceLocation: sourceLocation)
    }

    func disclosureShouldBeAbsent(_ section: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let found = try hasElement("inboxToggle-\(section.lowercased())")
        #expect(!found, "Disclosure \(section) should be absent", sourceLocation: sourceLocation)
    }

    func disclosureShouldShowCount(_ count: String, for section: String,
                                   sourceLocation: SourceLocation = #_sourceLocation) throws {
        let text = try sidebar.inspect().find(viewWithAccessibilityIdentifier: "inboxToggle-\(section.lowercased())")
            .button().labelView().find(text: count).string()
        #expect(text == count, "Disclosure \(section) should show \(count)", sourceLocation: sourceLocation)
    }

    func sessionShouldBeAbsent(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let found = try hasElement("inbox-\(id)")
        #expect(!found, "Session \(id) should be absent", sourceLocation: sourceLocation)
    }

    func moveToLaterShouldBeAbsent(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let found = try hasElement("moveLater-\(id)")
        #expect(!found, "Move to Later should be absent for \(id)", sourceLocation: sourceLocation)
    }

    func archiveShouldBeAbsent(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let found = try hasElement("archive-\(id)")
        #expect(!found, "Archive should be absent for \(id)", sourceLocation: sourceLocation)
    }

    func sessionShouldBeDisabled(_ id: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let disabled = try sidebar.inspect().find(viewWithAccessibilityIdentifier: "inbox-\(id)").button().isDisabled()
        #expect(disabled, "Session \(id) should be disabled", sourceLocation: sourceLocation)
    }

    func creationShouldBeDisabled(sourceLocation: SourceLocation = #_sourceLocation) throws {
        let disabled = try sidebar.inspect().find(viewWithAccessibilityIdentifier: "newInboxSession").button().isDisabled()
        #expect(disabled, "Session creation should be disabled", sourceLocation: sourceLocation)
    }

    func errorShouldBe(_ expected: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let text = try sidebar.inspect().find(viewWithAccessibilityIdentifier: "errorMessage").text().string()
        #expect(text == expected, "Sidebar should show the connection error", sourceLocation: sourceLocation)
    }

    func connectionStatusShouldBe(_ expected: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let text = try sidebar.inspect().find(viewWithAccessibilityIdentifier: "connectionStatus").text().string()
        #expect(text == expected, "Sidebar should show the connection status", sourceLocation: sourceLocation)
    }

    func openShouldHaveBeenRequested(_ target: ProjectSessionTarget, title: String,
                                     sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(openedTarget == target, "Open should receive the session target", sourceLocation: sourceLocation)
        #expect(openedTitle == title, "Open should receive the session title", sourceLocation: sourceLocation)
    }

    func creationShouldHaveBeenRequested(_ path: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(createdPath == path, "Creation should receive the project path", sourceLocation: sourceLocation)
    }

    func moveToLaterShouldHaveBeenRequested(_ path: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(movedPath == path, "Move to Later should receive the session path", sourceLocation: sourceLocation)
    }

    func archiveShouldHaveBeenRequested(_ path: String, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(archivedPath == path, "Archive should receive the session path", sourceLocation: sourceLocation)
    }

    func connectionShouldHaveBeenRequestedOnce(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(connectionRequests == 1, "Connection should be requested once", sourceLocation: sourceLocation)
    }

    func settingsShouldHaveBeenRequestedOnce(sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(settingsRequests == 1, "Settings should be requested once", sourceLocation: sourceLocation)
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
