import SwiftUI

/// Compact split view: project/history navigation beside one selected conversation.
/// Session selection remains application state, not native window-tab state.
struct MacWorkspaceScreen: View {
    let presentation: WorkspacePresentation
    let session: SessionPresentation
    let actions: WorkspaceActions

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            WorkspacePane(presentation: presentation, session: session, actions: actions)
        }
    }

    private var sidebar: some View {
        WorkspaceSidebar(presentation: presentation, onOpen: actions.open, onCreate: actions.create,
                         onConnection: actions.connection, onSettings: actions.settings)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
    }
}
