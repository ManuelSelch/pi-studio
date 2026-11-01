#if os(macOS)
import SwiftUI

/// Independent toolbar items preserve each action's accessibility identity and overflow behavior.
struct SessionWindowActions: ToolbarContent {
    let selection: WorkspaceSelection
    let status: String
    let actions: WorkspaceActions

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button { if let path = selection.sessionPath { actions.moveToLater(path) } } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .disabled(!selection.canMoveLater).help("Move to Later")
            .accessibilityLabel("Move to Later").accessibilityIdentifier("headerLater")
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) {
            Button { if let path = selection.sessionPath { actions.archive(path) } } label: {
                Image(systemName: "archivebox")
            }
            .disabled(selection.sessionPath == nil || selection.activity != nil).help("Archive session")
            .accessibilityLabel("Archive session").accessibilityIdentifier("headerArchive")
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) {
            Button { actions.closeTab(selection.tabId) } label: { Image(systemName: "xmark") }
                .help("Close session").accessibilityLabel("Close session").accessibilityIdentifier("headerClose")
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) {
            Button { actions.create(selection.context) } label: { Image(systemName: "plus") }
                .help("New session").accessibilityLabel("New session").accessibilityIdentifier("headerNew")
        }
        .sharedBackgroundVisibility(.hidden)
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 8) {
                SessionActivityIndicator(activity: selection.activity).accessibilityIdentifier("headerStatus")
                Text(status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityIdentifier("sessionStatus")
            }
        }
        .sharedBackgroundVisibility(.hidden)
    }
}
#endif
