import SwiftUI

/// The conversation pane: open-session tabs above the selected conversation, or a
/// deliberate empty workspace. It owns no lifecycle and no second connection.
struct WorkspacePane: View {
    let presentation: WorkspacePresentation
    let session: SessionPresentation
    let actions: WorkspaceActions
    @State private var showsOverview = false

    var body: some View {
        VStack(spacing: 0) {
            if !presentation.openSessions.isEmpty {
                HStack(spacing: 0) {
                    SessionTabStrip(tabs: presentation.openSessions,
                                    onSelect: actions.selectTab, onClose: actions.closeTab)
                    overviewButton
                }
            }
            if let selection = presentation.selection {
                WorkspaceConversation(selection: selection, session: session,
                                      onDraftChanged: actions.draftChanged,
                                      onSend: actions.send, onStop: actions.stop,
                                      onFollowTailChanged: actions.followTailChanged,
                                      onScrollAnchorChanged: actions.scrollAnchorChanged)
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

    /// The same overview the phone presents as a sheet. It shows no running count.
    private var overviewButton: some View {
        Button { showsOverview.toggle() } label: {
            Image(systemName: "list.bullet").font(.system(size: 11, weight: .semibold))
                .frame(width: 32, height: 40).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .background(.bar)
        .accessibilityLabel("Open sessions")
        .accessibilityIdentifier("sessionOverviewButton")
        .popover(isPresented: $showsOverview, arrowEdge: .bottom) {
            SessionOverview(sessions: presentation.openSessions,
                            newSessionPath: presentation.newSessionPath,
                            isBrowsing: presentation.selection == nil,
                            onSelect: { actions.selectTab($0); showsOverview = false },
                            onClose: actions.closeTab,
                            onNewSession: { actions.create($0); showsOverview = false },
                            onProjects: { actions.back(); showsOverview = false })
                .frame(width: 300, height: 360)
        }
    }

    private var surface: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}
