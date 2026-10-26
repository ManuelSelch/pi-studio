import FactoryKit
import Flux
import PiSDK
import SwiftUI

/// Bridges the workspace and its conversation for one platform shell.
/// Consent and cross-feature signals stay here; app-level settings presentation is a callback.
/// Screens receive plain values and callbacks, and every effect goes to a store.
public struct WorkspaceContainer: View {
    @InjectedObject(\.workspaceStore) private var store
    @InjectedObject(\.sessionStore) private var session
    @InjectedObject(\.settingsStore) private var settings
    @State private var confirmConnect = false
    @State private var confirmDisconnect = false

    private let onOpenSettings: @MainActor () -> Void

    public init(onOpenSettings: @escaping @MainActor () -> Void) {
        self.onOpenSettings = onOpenSettings
    }

    public var body: some View {
        screen
            .alert("Connect and take control?", isPresented: $confirmConnect) {
                Button("Cancel", role: .cancel) {}
                Button("Connect and take control") { store.dispatch(.connectRequested(takingControl: true)) }
            } message: {
                Text("This replaces any current server controller. Connecting does not create or close sessions.")
            }
            .alert("Disconnect?", isPresented: $confirmDisconnect) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) { store.dispatch(.disconnectRequested()) }
            } message: {
                Text("Server work may continue. Disconnecting does not stop or close the session.")
            }
            // A per-tab draft is only dropped once the send was admitted.
            .onChange(of: session.state.clearDraftMatching) { _, matching in
                guard let matching else { return }
                store.dispatch(.draftCleared(matching: matching))
                session.dispatch(.clearDraftConsumed)
            }
    }

    @ViewBuilder private var screen: some View {
        #if os(macOS)
        MacWorkspaceScreen(presentation: presentation, session: sessionPresentation, actions: actions)
        #else
        PhoneWorkspaceScreen(presentation: presentation, session: sessionPresentation, actions: actions)
        #endif
    }

    private var actions: WorkspaceActions {
        WorkspaceActions(
            open: { target, title in store.dispatch(.openRequested(target: target, title: title)) },
            create: { path in
                let quick = store.state.catalogue.projects.first { $0.path == path }?.quickChats == true
                store.dispatch(.createRequested(projectPath: path, title: quick ? "New chat" : "New session"))
            },
            connection: requestConnectionChange,
            settings: onOpenSettings,
            back: { store.dispatch(.back) },
            draftChanged: { store.dispatch(.draftChanged($0)) },
            send: { text in session.dispatch(.sendRequested(text: text)) },
            stop: { session.dispatch(.stopRequested()) },
            selectTab: { id in store.dispatch(.selectRequested(id: id)) },
            closeTab: { store.dispatch(.closeSession($0)) },
            followTailChanged: { store.dispatch(.followTailChanged($0)) },
            scrollAnchorChanged: { store.dispatch(.scrollAnchorChanged($0)) })
    }

    private func requestConnectionChange() {
        if store.state.canConnect { confirmConnect = true }
        else if requiresDisconnectWarning { confirmDisconnect = true }
        else { store.dispatch(.disconnectRequested()) }
    }

    /// A disconnect is confirmed when the conversation or any server runtime is still working.
    private var requiresDisconnectWarning: Bool {
        store.state.requiresDisconnectWarning || session.state.requiresDisconnectWarning
    }

    private var presentation: WorkspacePresentation {
        let workspace = store.state
        var value = WorkspacePresentation()
        value.status = workspace.selectedSessionId == nil ? workspace.status : session.state.statusText
        value.canConnect = workspace.canConnect
        value.isBusy = workspace.isOpening
        value.canOpen = workspace.canOpen
        value.requiresDisconnectWarning = requiresDisconnectWarning
        value.error = workspace.selectedSessionId == nil ? workspace.error : nil
        value.groups = ProjectListModel.groups(workspace.catalogue)
        value.isConnected = workspace.isConnected
        value.openSessions = Self.openSessions(workspace)
        value.newSessionPath = Self.newSessionPath(workspace.catalogue)
        value.selection = workspace.selectedSession.map {
            WorkspaceSelection(title: $0.title, runtimeId: $0.runtimeId,
                               sessionPath: $0.sessionPath, context: $0.projectPath)
        }
        return value
    }

    /// Open sessions as both shells render them; the project keeps titles unambiguous.
    static func openSessions(_ workspace: WorkspaceFeature.State) -> [OpenSessionPresentation] {
        workspace.openSessions.map {
            OpenSessionPresentation(id: $0.id, title: $0.title, activity: $0.activity,
                                    isSelected: $0.id == workspace.selectedSessionId,
                                    unread: $0.unread, context: $0.projectPath)
        }
    }

    /// Quick Chats first, then the first project: the overview never picks a project by accident.
    static func newSessionPath(_ catalogue: PiCatalogue) -> String? {
        let groups = ProjectListModel.groups(catalogue)
        return (groups.first { $0.quickChats } ?? groups.first)?.newSessionPath
    }

    /// A locked composer always says why: running, stopping or not attached yet.
    func composerHint(_ state: SessionFeature.State) -> String {
        if state.isSending || state.projection?.status == .starting { return "Sending… Stop to edit." }
        if state.isStopping || state.projection?.status == .aborting { return "Stopping…" }
        if state.projection?.status == .running { return "Generating… Stop to edit." }
        if state.connection == .connecting { return "Waiting for the session…" }
        if state.connection == .disconnected { return "No session attached." }
        return ""
    }

    private var sessionPresentation: SessionPresentation {
        let state = session.state
        let tab = store.state.selectedSession
        var value = SessionPresentation()
        value.title = tab?.title ?? "Pi Studio"
        value.status = state.statusText
        value.details = tab?.projectPath ?? ""
        value.error = state.errorMessage
        value.draft = store.state.draft
        value.followTail = store.state.followTail
        value.scrollAnchor = store.state.scrollAnchor
        value.placeholder = state.connection == .disconnected ? "Open a session to start." : "Start a conversation."
        value.hint = composerHint(state)
        value.canConnect = false
        value.canEditMessage = state.canEditMessage
        value.canSend = state.canSend
        value.canStop = state.canStop && !settings.state.isPresented
        value.isStopping = state.isStopping || state.projection?.status == .aborting
        value.requiresDisconnectWarning = requiresDisconnectWarning
        value.messages = (state.projection?.messages ?? []).map {
            TranscriptMessage(id: $0.id, role: $0.role == "user" ? "You" : $0.role.capitalized, text: $0.text)
        }
        return value
    }
}
