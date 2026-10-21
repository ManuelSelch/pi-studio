import SwiftUI

/// iPhone navigation: projects are the root list and the conversation is pushed.
/// There is no tab strip; overview switching arrives in a later slice.
struct PhoneWorkspaceScreen: View {
    let presentation: WorkspacePresentation
    let session: SessionPresentation
    let actions: WorkspaceActions

    var body: some View {
        NavigationStack {
            sidebar
                .navigationTitle("Pi Studio")
                .phoneTitleDisplayMode()
                .navigationDestination(isPresented: showsConversation) { conversation }
        }
    }

    private var sidebar: some View {
        WorkspaceSidebar(presentation: presentation, onOpen: actions.open, onCreate: actions.create,
                         onConnection: actions.connection, onSettings: actions.settings)
    }

    /// The store stays authoritative: dismissing the pushed view deselects there.
    private var showsConversation: Binding<Bool> {
        Binding(get: { presentation.selection != nil },
                set: { presented in if !presented { actions.back() } })
    }

    @ViewBuilder private var conversation: some View {
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

private extension View {
    /// Inline titles are iPhone-only; the same screen must still compile on macOS.
    @ViewBuilder func phoneTitleDisplayMode() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
