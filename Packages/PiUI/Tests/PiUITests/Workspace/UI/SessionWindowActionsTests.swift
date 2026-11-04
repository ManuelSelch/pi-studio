#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import PiUI

@MainActor
struct SessionWindowActionsTests {
    private func window(selection: WorkspaceSelection, actions: WorkspaceActions) -> NSWindow {
        let content = SessionWindowActions(selection: selection, status: "Ready", actions: actions)
        let hosting = NSHostingView(rootView: Text("Session").toolbar { content })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        return window
    }

    @Test func toolbarContainsSessionActions() throws {
        let selection = WorkspaceSelection(title: "Chat", runtimeId: "runtime", sessionPath: "/saved",
                                           context: "/repo", canMoveLater: true, tabId: "tab")
        let actions = WorkspaceActions(open: { _, _ in }, create: { _ in }, connection: {}, settings: {},
                                       back: {}, draftChanged: { _ in }, send: { _ in }, stop: {},
                                       selectTab: { _ in }, closeTab: { _ in }, followTailChanged: { _ in },
                                       scrollAnchorChanged: { _ in })
        let window = window(selection: selection, actions: actions)
        let toolbar = try #require(window.toolbar)

        #expect(toolbar.items.count == 5)
        #expect(toolbar.items.allSatisfy { $0.view != nil })
    }
}
#endif
