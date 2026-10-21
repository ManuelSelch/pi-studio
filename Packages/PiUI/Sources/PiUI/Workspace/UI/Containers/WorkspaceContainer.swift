import SwiftUI
import Flux

/// Bridges the workspace stores to one platform shell. Consent, settings
/// presentation and navigation actions stay here; screens get plain values.
public struct WorkspaceContainer: View {
    private let controller: WorkspaceController
    private let settings: SettingsController
    @ObservedObject private var store: FluxStore<WorkspaceFeature>
    @ObservedObject private var sessionStore: FluxStore<SessionFeature>
    @ObservedObject private var settingsStore: FluxStore<SettingsFeature>
    @State private var confirmConnect = false
    @State private var confirmDisconnect = false

    public init(dependencies: SessionDependencies) {
        self.init(controller: dependencies.workspaceController(),
                  settings: dependencies.settingsController())
    }

    public init(controller: WorkspaceController, settings: SettingsController) {
        self.controller = controller
        self.settings = settings
        _store = ObservedObject(wrappedValue: controller.store)
        _sessionStore = ObservedObject(wrappedValue: controller.session.store)
        _settingsStore = ObservedObject(wrappedValue: settings.store)
    }

    public var body: some View {
        screen
            .sheet(isPresented: Binding(get: { settingsStore.state.isPresented },
                                        set: { if !$0 { settings.cancel() } })) {
                SettingsContainer(controller: settings)
            }
            .alert("Connect and take control?", isPresented: $confirmConnect) {
                Button("Cancel", role: .cancel) {}
                Button("Connect and take control") {
                    Task { await controller.connect(takingControl: true) }
                }
            } message: {
                Text("This replaces any current server controller. Connecting does not create or close sessions.")
            }
            .alert("Disconnect?", isPresented: $confirmDisconnect) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    Task { await controller.disconnect() }
                }
            } message: {
                Text("Server work may continue. Disconnecting does not stop or close the session.")
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
            open: { target, title in Task { await controller.open(target, title: title) } },
            create: { path in Task { await controller.createSession(projectPath: path) } },
            connection: requestConnectionChange,
            settings: settings.open,
            back: controller.back,
            draftChanged: controller.setDraft,
            send: { Task { await controller.session.send() } },
            stop: { Task { await controller.session.stop() } },
            selectTab: { id in Task { await controller.selectSession(id: id) } },
            closeTab: { id in Task { await controller.closeSession(id: id) } },
            followTailChanged: controller.setFollowTail,
            scrollAnchorChanged: controller.setScrollAnchor)
    }

    private func requestConnectionChange() {
        if store.state.canConnect { confirmConnect = true }
        else if controller.requiresDisconnectWarning { confirmDisconnect = true }
        else { Task { await controller.disconnect() } }
    }

    private var presentation: WorkspacePresentation {
        let projects = store.state
        var value = WorkspacePresentation()
        value.status = projects.selectedSessionId == nil ? projects.status : sessionStore.state.statusText
        value.canConnect = projects.canConnect
        value.isBusy = projects.isOpening
        value.canOpen = projects.canOpen && controller.canNavigate
        value.requiresDisconnectWarning = controller.requiresDisconnectWarning
        value.error = projects.selectedSessionId == nil ? projects.error : nil
        value.groups = ProjectListModel.groups(projects.catalogue)
        value.selection = projects.selectedSession.map {
            WorkspaceSelection(title: $0.title, runtimeId: $0.runtimeId,
                               sessionPath: $0.sessionPath, context: $0.projectPath)
        }
        value.tabs = projects.openSessions.map {
            SessionTabPresentation(id: $0.id, title: $0.title, activity: $0.activity,
                                   isSelected: $0.id == projects.selectedSessionId, unread: $0.unread)
        }
        return value
    }

    private var sessionPresentation: SessionPresentation {
        let state = sessionStore.state
        var value = SessionPresentation()
        value.title = store.state.selectedSession?.title ?? "Pi Studio"
        value.status = state.statusText
        value.details = store.state.selectedSession?.projectPath ?? ""
        value.error = state.errorMessage
        value.draft = state.draft
        value.followTail = store.state.selectedSession?.followTail ?? true
        value.scrollAnchor = store.state.selectedSession?.scrollAnchor
        value.hint = state.hint
        value.placeholder = "Start a conversation."
        value.canConnect = false
        value.canEditMessage = state.canEditMessage
        value.canSend = state.canSend
        value.canStop = state.canStop
        value.requiresDisconnectWarning = state.requiresDisconnectWarning
        value.messages = (state.projection?.messages ?? []).map {
            TranscriptMessage(id: $0.id, role: $0.role == "user" ? "You" : $0.role.capitalized, text: $0.text)
        }
        return value
    }
}
