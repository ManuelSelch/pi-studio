import SwiftUI

/// Compact split view: project navigation beside one selected conversation.
/// No tab strip yet; independent session tabs arrive with multi-session SDK support.
struct MacWorkspaceScreen: View {
    let presentation: WorkspacePresentation
    let session: SessionPresentation
    let actions: WorkspaceActions

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
    }

    private var sidebar: some View {
        WorkspaceSidebar(presentation: presentation, onOpen: actions.open, onCreate: actions.create,
                         onConnection: actions.connection, onSettings: actions.settings)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
    }

    @ViewBuilder private var detail: some View {
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
}
