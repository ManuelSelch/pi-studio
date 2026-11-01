import FactoryKit
import Flux
import PiSDK
import SwiftUI

/// Bridges the workspace and its conversation for one platform shell.
/// Launch connection, cross-feature signals and app-level settings presentation stay here.
/// Screens receive plain values and callbacks, and every effect goes to a store.
public struct WorkspaceContainer: View {
    @InjectedObject(\.workspaceStore) private var store
    @InjectedObject(\.sessionStore) private var session
    @State private var confirmDisconnect = false
    @State private var composerDraft = ""
    @State private var didRequestLaunchConnection = false
    @State private var quickSwitcherOpen = false
    @State private var quickSwitcherQuery = ""

    private let onOpenSettings: @MainActor () -> Void
    private let isSettingsPresented: Bool

    public init(onOpenSettings: @escaping @MainActor () -> Void,
                isSettingsPresented: Bool = false) {
        self.onOpenSettings = onOpenSettings
        self.isSettingsPresented = isSettingsPresented
    }

    public var body: some View {
        screen
            .overlay {
                if quickSwitcherOpen && store.state.selectedSessionId != nil {
                    QuickSwitcherDialog(presentation: presentation, actions: actions)
                }
            }
            .background {
                #if os(macOS)
                Group {
                    Button("Quick Switcher", action: showQuickSwitcher).keyboardShortcut("k", modifiers: .command)
                    Button("Open Quick Switcher", action: showQuickSwitcher).keyboardShortcut("o", modifiers: .command)
                }.frame(width: 0, height: 0).opacity(0.001).allowsHitTesting(false)
                #endif
            }
            .task {
                guard !didRequestLaunchConnection else { return }
                didRequestLaunchConnection = true
                #if DEBUG
                guard ProcessInfo.processInfo.environment["PI_UI_DISABLE_AUTO_CONNECT"] != "1" else { return }
                #endif
                store.dispatch(.connectRequested(takingControl: true))
            }
            .alert("Disconnect?", isPresented: $confirmDisconnect) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) { store.dispatch(.disconnectRequested()) }
            } message: {
                Text("Server work may continue. Disconnecting does not stop or close the session.")
            }
            .onChange(of: session.state.clearDraftMatching) { _, matching in
                guard let matching else { return }
                if composerDraft == matching { composerDraft = "" }
                session.dispatch(.clearDraftConsumed)
            }
            .onChange(of: store.state.selectedSessionId) { _, _ in
                composerDraft = ""
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
        var value = WorkspaceActions(
            open: { target, title in store.dispatch(.openRequested(target: target, title: title)) },
            create: { path in
                let quick = store.state.catalogue.projects.first { $0.path == path }?.quickChats == true
                store.dispatch(.createRequested(projectPath: path, title: quick ? "New chat" : "New session"))
            },
            moveToLater: { store.dispatch(.moveToLaterRequested(path: $0)) },
            connection: requestConnectionChange,
            settings: onOpenSettings,
            back: { store.dispatch(.back) },
            draftChanged: { composerDraft = $0 },
            send: { text in session.dispatch(.sendRequested(text: text)) },
            stop: { session.dispatch(.stopRequested()) },
            selectTab: { id in store.dispatch(.selectRequested(id: id)) },
            closeTab: { store.dispatch(.closeSession($0)) },
            followTailChanged: { store.dispatch(.followTailChanged($0)) },
            scrollAnchorChanged: { store.dispatch(.scrollAnchorChanged($0)) })
        value.archive = { store.dispatch(.archiveRequested(path: $0)) }
        value.openQuickSwitcher = showQuickSwitcher
        value.dismissQuickSwitcher = { quickSwitcherOpen = false }
        value.quickSwitcherQueryChanged = { quickSwitcherQuery = $0 }
        value.chooseQuickSwitcherItem = { item in
            guard item.enabled else { return }
            quickSwitcherOpen = false
            if let target = item.target {
                store.dispatch(.openRequested(target: target, title: item.title))
            } else {
                let quick = store.state.catalogue.projects.first { $0.path == item.projectPath }?.quickChats == true
                store.dispatch(.createRequested(projectPath: item.projectPath, title: quick ? "New chat" : "New session"))
            }
        }
        return value
    }

    private func showQuickSwitcher() {
        guard !isSettingsPresented && !confirmDisconnect else { return }
        quickSwitcherQuery = ""
        quickSwitcherOpen = true
    }

    private func requestConnectionChange() {
        if store.state.canConnect { store.dispatch(.connectRequested(takingControl: true)) }
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
        value.inboxSessions = SessionInboxModel.sessions(workspace.catalogue, laterPaths: workspace.laterSessionPaths)
        value.isConnected = workspace.isConnected
        value.quickSwitcherOpen = quickSwitcherOpen
        value.quickSwitcherQuery = quickSwitcherQuery
        value.quickSwitcherItems = QuickSwitcherModel.results(catalogue: workspace.catalogue, query: quickSwitcherQuery)
        value.openSessions = Self.openSessions(workspace)
        value.newSessionPath = Self.newSessionPath(workspace.catalogue)
        value.selection = workspace.selectedSession.map { tab in
            let projectName = workspace.catalogue.projects.first { $0.path == tab.projectPath }?.name
                ?? workspace.catalogue.sessions.first { $0.sessionId == tab.runtimeId }?.projectName
                ?? URL(fileURLWithPath: tab.projectPath).lastPathComponent
            let canMoveLater = value.inboxSessions.contains { $0.row.sessionPath == tab.sessionPath && $0.canMoveLater }
            return WorkspaceSelection(title: tab.title, runtimeId: tab.runtimeId,
                                      sessionPath: tab.sessionPath, context: tab.projectPath,
                                      projectName: projectName, activity: tab.activity,
                                      canMoveLater: canMoveLater, tabId: tab.id)
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
        value.draft = composerDraft
        value.status = state.statusText
        value.details = tab?.projectPath ?? ""
        value.error = state.errorMessage ?? store.state.error
        value.draft = composerDraft
        value.followTail = store.state.followTail
        value.scrollAnchor = store.state.scrollAnchor
        value.placeholder = state.connection == .disconnected ? "Open a session to start." : "Start a conversation."
        value.hint = composerHint(state)
        value.canConnect = false
        value.canEditMessage = state.canEditMessage
        value.canSend = state.canSend
        value.canStop = state.canStop && !isSettingsPresented && !quickSwitcherOpen
        value.isQuickSwitcherPresented = quickSwitcherOpen
        value.isStopping = state.isStopping || state.projection?.status == .aborting
        value.requiresDisconnectWarning = requiresDisconnectWarning
        value.messages = (state.projection?.messages ?? []).map {
            TranscriptMessage(id: $0.id, role: $0.role == "user" ? "You" : $0.role.capitalized, text: $0.text)
        }
        return value
    }
}
