#if os(macOS)
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
        .navigationTitle(presentation.selection == nil ? "Pi Studio" : "")
        .toolbar {
            if let selection = presentation.selection {
                ToolbarItem(placement: .navigation) {
                    HStack(spacing: 8) {
                        Text(selection.projectName).foregroundStyle(.secondary).lineLimit(1)
                            .accessibilityIdentifier("sessionContext")
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        Text(selection.title).font(.headline).lineLimit(1)
                            .accessibilityIdentifier("sessionTitle")
                    }
                }
                .sharedBackgroundVisibility(.hidden)
                SessionWindowActions(selection: selection, status: session.status, actions: actions)
            }
        }
    }

    private var sidebar: some View {
        WorkspaceSidebar(presentation: presentation, onOpen: actions.open, onCreate: actions.create,
                         onMoveToLater: actions.moveToLater,
                         onConnection: actions.connection, onSettings: actions.settings)
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
    }
}
#endif
