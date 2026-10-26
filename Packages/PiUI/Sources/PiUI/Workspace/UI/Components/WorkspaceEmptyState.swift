import SwiftUI

/// Deliberate empty workspace: explains the connection state and offers the only
/// two relevant actions instead of showing a disabled conversation.
struct WorkspaceEmptyState: View {
    let status: String
    let error: String?
    let canConnect: Bool
    let isBusy: Bool
    let onConnect: @MainActor () -> Void
    let onSettings: @MainActor () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: canConnect ? "bolt.horizontal.circle" : "rectangle.stack.badge.play")
                .font(.system(size: 34)).foregroundStyle(.secondary)
            Text(canConnect ? "Not connected" : isBusy ? "Loading projects…" : "Pick a session")
                .font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let error {
                Text(verbatim: error).font(.subheadline).foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("workspaceError")
            }
            HStack(spacing: 8) {
                if canConnect {
                    Button("Connect and take control", action: onConnect).buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("workspaceConnectButton")
                }
                Button("Settings", action: onSettings).buttonStyle(.bordered)
                    .accessibilityIdentifier("workspaceSettingsButton")
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("workspaceEmptyState")
    }

    private var message: String {
        if error != nil { return "\(status). Fix the connection before continuing." }
        if canConnect { return "Connect to the server to browse projects, history and Quick Chats." }
        if isBusy { return "Waiting for the server catalogue." }
        return "Choose a session from the sidebar, or start a new one in a project."
    }
}
