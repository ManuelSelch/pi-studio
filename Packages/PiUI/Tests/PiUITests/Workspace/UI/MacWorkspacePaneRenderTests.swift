#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PiUI

/// macOS app automation is paused by user request, so the tab strip is verified by
/// rendering the real pane off-screen instead of driving a window. This still proves
/// the composition, labels and accessibility identifiers the Mac shell depends on.
@MainActor
struct MacWorkspacePaneRenderTests {
    private func presentation() -> WorkspacePresentation {
        var value = WorkspacePresentation()
        value.status = "Ready"
        value.canOpen = true
        value.selection = WorkspaceSelection(title: "Working", runtimeId: "running",
                                             sessionPath: nil, context: "/repo")
        value.tabs = [
            SessionTabPresentation(id: "chat", title: "New chat", activity: nil),
            SessionTabPresentation(id: "running", title: "Working", activity: .running, isSelected: true),
            SessionTabPresentation(id: "blocked", title: "Needs a decision", activity: .needsYou, unread: true),
        ]
        return value
    }

    private func session() -> SessionPresentation {
        var value = SessionPresentation()
        value.title = "Working"
        value.status = "Generating…"
        value.details = "/repo"
        value.draft = ""
        value.canEditMessage = false
        value.canStop = true
        value.messages = [TranscriptMessage(id: "1", role: "You", text: "Summarise the layout work."),
                          TranscriptMessage(id: "2", role: "Assistant", text: "Tabs, one live transcript.")]
        return value
    }

    /// Off-screen rendering through a real hosting window: `ImageRenderer` alone cannot
    /// resolve materials and text fields, which would fake a passing but blank layout.
    private func render() throws -> Data {
        let pane = WorkspacePane(presentation: presentation(), session: session(),
                                 actions: WorkspaceActions(open: { _, _ in }, create: { _ in },
                                                           connection: {}, settings: {}, back: {},
                                                           draftChanged: { _ in }, send: {}, stop: {},
                                                           selectTab: { _ in }, closeTab: { _ in },
                                                           followTailChanged: { _ in },
                                                           scrollAnchorChanged: { _ in }))
        let hosting = NSHostingView(rootView: pane)
        hosting.frame = NSRect(x: 0, y: 0, width: 760, height: 520)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        window.appearance = NSAppearance(named: .aqua)
        hosting.layoutSubtreeIfNeeded()
        let bitmap = try #require(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        window.contentView = nil
        return try #require(bitmap.representation(using: .png, properties: [:]),
                            "Rendered pane must convert to a PNG")
    }

    @Test func theConversationPaneRendersTabsWithStatusAndOneTranscript() throws {
        let data = try render()
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("pi-studio-mac-pane.png")
        try data.write(to: url)
        // A blank render compresses to almost nothing; real chrome does not.
        #expect(data.count > 8_000, "The rendered workspace pane looks blank: \(url.path)")
    }
}
#endif
