import SwiftUI
import Flux

public struct ProjectsContainer: View {
    private let controller: ProjectsController
    @ObservedObject private var store: FluxStore<ProjectsFeature>
    @ObservedObject private var sessionStore: FluxStore<SessionFeature>

    public init(dependencies: SessionDependencies) {
        let controller = dependencies.projectsController()
        self.controller = controller
        _store = ObservedObject(wrappedValue: controller.store)
        _sessionStore = ObservedObject(wrappedValue: controller.session.store)
    }
    public var body: some View {
        ProjectsScreen(presentation: presentation,
                       onConnect: { Task { await controller.connect(takingControl: true) } },
                       onDisconnect: { Task { await controller.disconnect() } },
                       onBack: controller.back,
                       onOpen: { target, title in Task { await controller.open(target, title: title) } },
                       onCreate: { path in Task { await controller.createSession(projectPath: path) } }) {
            SessionContainer(controller: controller.session, embedded: true)
        }
    }
    private var presentation: ProjectsPresentation {
        let state = store.state
        var value = ProjectsPresentation()
        value.status = state.selected != nil && !state.isOpening ? sessionStore.state.statusText : state.status
        value.canConnect = state.canConnect
        value.isConnected = state.isConnected
        value.isOpening = state.isOpening
        value.canNavigate = controller.canNavigate
        value.canOpen = state.canOpen && controller.canNavigate
        value.requiresDisconnectWarning = controller.requiresDisconnectWarning
        value.selectedTitle = state.selected == nil ? nil : state.title
        value.error = state.selected == nil ? state.error : nil
        value.groups = ProjectListModel.groups(state.catalogue)
        return value
    }
}
