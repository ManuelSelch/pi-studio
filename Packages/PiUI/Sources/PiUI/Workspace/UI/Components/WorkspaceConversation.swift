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

    var body: some View {
        VStack(spacing: 0) {
            #if !os(macOS)
            HStack(spacing: 8) {
                Text(selection.projectName).foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityIdentifier("sessionContext")
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                Text(selection.title).font(.headline).lineLimit(1)
                    .accessibilityIdentifier("sessionTitle")
                Spacer(minLength: 4)
                SessionActivityIndicator(activity: selection.activity)
                    .accessibilityIdentifier("headerStatus")
                Text(session.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityIdentifier("sessionStatus")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 8)
            Divider()
            #endif
            SessionScreen(presentation: session, onDraftChanged: onDraftChanged, onConnect: {}, onDisconnect: {}, onSend: onSend, onStop: onStop,
                          onFollowTailChanged: onFollowTailChanged,
                          onScrollAnchorChanged: onScrollAnchorChanged,
                          showsHeader: false, maxContentWidth: 760)
            #if os(macOS)
                .id(selection.tabId)
            #endif
        }
    }
}
