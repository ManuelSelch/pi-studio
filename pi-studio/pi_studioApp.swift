import SwiftUI
import FactoryKit
import PiUI

@main
struct pi_studioApp: App {
    @State private var dependencies: SessionDependencies
    @Environment(\.scenePhase) private var scenePhase
    private var workspace: ProjectsController { dependencies.projectsController() }

    init() {
        let dependencies = SessionDependencies()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let arguments = ProcessInfo.processInfo.arguments
            let suiteIndex = arguments.firstIndex(of: "--ui-settings-suite")
            let suite = suiteIndex.flatMap { index in
                arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
            }
            let suiteName = suite?.hasPrefix("PiStudio.UITests.") == true
                ? suite! : "PiStudio.UITests." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suiteName)!
            if arguments.contains("--ui-reset-settings") {
                defaults.removePersistentDomain(forName: suiteName)
            }
            let service = UserDefaultsEndpointSettingsService(defaults: defaults)
            dependencies.endpointSettingsService.register { service }
            let rejected = ProcessInfo.processInfo.arguments.contains("--ui-send-rejected")
            let unknown = ProcessInfo.processInfo.arguments.contains("--ui-send-unknown")
            let rejectOpen = ProcessInfo.processInfo.arguments.contains("--ui-open-rejected")
            let connection = UITestConnection(rejectSend: rejected, unknownSend: unknown, rejectOpen: rejectOpen)
            dependencies.makeConnection.register { { _ in connection } }
            dependencies.makeSessionConnection.register { { _ in connection } }
        }
        #endif
        _dependencies = State(initialValue: dependencies)
    }

    var body: some Scene {
        #if os(macOS)
        // One window and one shared connection. Losing focus is not a disconnect.
        Window("Pi Studio", id: "workspace") {
            WorkspaceContainer(dependencies: dependencies)
                .frame(minWidth: 620, minHeight: 500)
                .onDisappear { Task { await workspace.disconnect() } }
        }
        .defaultSize(width: 980, height: 760)
        #else
        WindowGroup {
            WorkspaceContainer(dependencies: dependencies)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await workspace.disconnect() } }
                }
        }
        #endif
    }
}
