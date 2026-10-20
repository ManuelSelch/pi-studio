import SwiftUI

struct ProjectsPresentation {
    var status = "Disconnected"
    var canConnect = true
    var isConnected = false
    var isOpening = false
    var canNavigate = true
    var canOpen = false
    var requiresDisconnectWarning = false
    var selectedTitle: String?
    var error: String?
    var groups: [ProjectGroup] = []
}

/// Layout and UI-only disclosure/confirmation state. No services, stores or SDK.
struct ProjectsScreen<Conversation: View>: View {
    let presentation: ProjectsPresentation
    let onConnect: @MainActor () -> Void
    let onDisconnect: @MainActor () -> Void
    let onBack: @MainActor () -> Void
    let onOpen: @MainActor (ProjectSessionTarget, String) -> Void
    let onCreate: @MainActor (String) -> Void
    @ViewBuilder let conversation: () -> Conversation
    @State private var confirmConnect = false
    @State private var confirmDisconnect = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    if presentation.selectedTitle != nil {
                        Button(action: onBack) { Label("Projects", systemImage: "chevron.left") }
                            .buttonStyle(.plain).foregroundStyle(.tint)
                            .disabled(!presentation.canNavigate)
                            .accessibilityIdentifier("projectsBack")
                    }
                    Text(presentation.status).font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("connectionStatus")
                    Spacer(minLength: 4)
                    Button(presentation.canConnect ? "Connect" : "Disconnect") {
                        if presentation.canConnect { confirmConnect = true }
                        else if presentation.requiresDisconnectWarning { confirmDisconnect = true }
                        else { onDisconnect() }
                    }
                    .buttonStyle(.plain).foregroundStyle(.tint)
                    .frame(minHeight: 44).accessibilityIdentifier("connectButton")
                }
                if let title = presentation.selectedTitle {
                    Text(title).font(.headline).padding(.bottom, 8)
                        .accessibilityIdentifier("sessionTitle")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 4)
            Divider()
            if let error = presentation.error {
                Text(verbatim: error).font(.subheadline).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16).padding(.top, 8)
                    .accessibilityIdentifier("errorMessage")
            }
            if presentation.selectedTitle != nil {
                conversation()
            } else if presentation.isConnected && !presentation.groups.isEmpty {
                ProjectList(groups: presentation.groups, canOpen: presentation.canOpen,
                            onOpen: onOpen, onCreate: onCreate)
            } else {
                VStack(spacing: 10) {
                    if !presentation.canConnect { ProgressView() }
                    Text(presentation.canConnect ? "Connect to browse projects and sessions." : "Waiting for projects…")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: 560, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .alert("Connect and take control?", isPresented: $confirmConnect) {
            Button("Cancel", role: .cancel) {}
            Button("Connect and take control", action: onConnect)
        } message: {
            Text("This replaces any current server controller. Connecting does not create or close sessions.")
        }
        .alert("Disconnect?", isPresented: $confirmDisconnect) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive, action: onDisconnect)
        } message: {
            Text("Server work may continue. Disconnecting does not stop or close sessions.")
        }
    }
}
