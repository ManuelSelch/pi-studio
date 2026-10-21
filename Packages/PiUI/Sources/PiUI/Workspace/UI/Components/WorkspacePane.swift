import SwiftUI

/// The conversation pane: open-session tabs above the selected conversation, or a
/// deliberate empty workspace. It owns no lifecycle and no second connection.
struct WorkspacePane: View {
    let presentation: WorkspacePresentation
    let session: SessionPresentation
    let actions: WorkspaceActions

    var body: some View {
        VStack(spacing: 0) {
            if !presentation.tabs.isEmpty {
                SessionTabStrip(tabs: presentation.tabs, onSelect: actions.selectTab, onClose: actions.closeTab)
            }
            if let selection = presentation.selection {
                WorkspaceConversation(selection: selection, session: session,
                                      onDraftChanged: actions.draftChanged,
                                      onSend: actions.send, onStop: actions.stop)
            } else {
                WorkspaceEmptyState(status: presentation.status, error: presentation.error,
                                    canConnect: presentation.canConnect, isBusy: presentation.isBusy,
                                    onConnect: actions.connection, onSettings: actions.settings)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The pane paints its own surface: the tab strip and the conversation header
        // must not depend on whatever a parent happens to draw behind them.
        .background(surface)
    }

    private var surface: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}
