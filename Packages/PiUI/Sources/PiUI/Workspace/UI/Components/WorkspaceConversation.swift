import SwiftUI

/// One selected conversation: project context, notices and the shared transcript
/// and composer. It never owns connection or session lifecycle.
struct WorkspaceConversation: View {
    let selection: WorkspaceSelection
    let session: SessionPresentation
    let onDraftChanged: @MainActor (String) -> Void
    let onSend: @MainActor () -> Void
    let onStop: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selection.title).font(.headline).lineLimit(1)
                    .accessibilityIdentifier("sessionTitle")
                Text(selection.context).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityIdentifier("sessionContext")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 8)
            Divider()
            SessionScreen(presentation: session, onDraftChanged: onDraftChanged,
                          onConnect: {}, onDisconnect: {}, onSend: onSend, onStop: onStop,
                          showsHeader: false, maxContentWidth: 760)
        }
    }
}
