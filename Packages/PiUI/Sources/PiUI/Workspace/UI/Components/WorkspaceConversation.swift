import SwiftUI

/// One selected conversation: project context, notices and the shared transcript
/// and composer. It never owns connection or session lifecycle.
struct WorkspaceConversation: View {
    let selection: WorkspaceSelection
    let session: SessionPresentation
    let onDraftChanged: @MainActor (String) -> Void
    let onSend: @MainActor (String) -> Void
    let onStop: @MainActor () -> Void
    let onFollowTailChanged: @MainActor (Bool) -> Void
    let onScrollAnchorChanged: @MainActor (String?) -> Void
    var actions: WorkspaceActions? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(selection.projectName).foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityIdentifier("sessionContext")
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                Text(selection.title).font(.headline).lineLimit(1)
                    .accessibilityIdentifier("sessionTitle")
                Spacer(minLength: 4)
                #if os(macOS)
                if let actions {
                    Button { if let path = selection.sessionPath { actions.moveToLater(path) } } label: { Image(systemName: "clock.arrow.circlepath").frame(width: 30, height: 32) }
                        .disabled(!selection.canMoveLater).help("Move to Later").accessibilityIdentifier("headerLater")
                    Button { if let path = selection.sessionPath { actions.archive(path) } } label: { Image(systemName: "archivebox").frame(width: 30, height: 32) }
                        .disabled(selection.sessionPath == nil || selection.activity != nil).help("Archive session").accessibilityIdentifier("headerArchive")
                    Button { actions.closeTab(selection.tabId) } label: { Image(systemName: "xmark").frame(width: 30, height: 32) }
                        .help("Close session").accessibilityIdentifier("headerClose")
                    Button { actions.create(selection.context) } label: { Image(systemName: "plus").frame(width: 30, height: 32) }
                        .help("New session").accessibilityIdentifier("headerNew")
                }
                #endif
                SessionActivityIndicator(activity: selection.activity)
                    .accessibilityIdentifier("headerStatus")
                Text(session.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityIdentifier("sessionStatus")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 8)
            Divider()
            SessionScreen(presentation: session, onDraftChanged: onDraftChanged, onConnect: {}, onDisconnect: {}, onSend: onSend, onStop: onStop,
                          onFollowTailChanged: onFollowTailChanged,
                          onScrollAnchorChanged: onScrollAnchorChanged,
                          showsHeader: false, maxContentWidth: 760)
        }
    }
}
