import SwiftUI

/// The conversation pane or home screen. Session switching stays in the
/// project/history sidebar; this pane owns no lifecycle or second connection.
struct WorkspacePane: View {
    let presentation: WorkspacePresentation
    let session: SessionPresentation
    let actions: WorkspaceActions
    var body: some View {
        VStack(spacing: 0) {
            if let selection = presentation.selection {
                WorkspaceConversation(selection: selection, session: session,
                                      onDraftChanged: actions.draftChanged, onSend: actions.send, onStop: actions.stop,
                                      onFollowTailChanged: actions.followTailChanged,
                                      onScrollAnchorChanged: actions.scrollAnchorChanged)
            } else {
                WorkspaceHome(presentation: presentation, onRetry: actions.connection)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The pane paints its own surface so the conversation header does not
        // depend on whatever a parent happens to draw behind it.
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
