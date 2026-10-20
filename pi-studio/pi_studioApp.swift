import SwiftUI
import FactoryKit
import PiUI

@main
struct pi_studioApp: App {
    @State private var dependencies: SessionDependencies
    @Environment(\.scenePhase) private var scenePhase
    private var projects: ProjectsController { dependencies.projectsController() }

    init() {
        let dependencies = SessionDependencies()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let rejected = ProcessInfo.processInfo.arguments.contains("--ui-send-rejected")
            let unknown = ProcessInfo.processInfo.arguments.contains("--ui-send-unknown")
            let rejectOpen = ProcessInfo.processInfo.arguments.contains("--ui-open-rejected")
            dependencies.makeSessionConnection.register {
                { _ in UITestConnection(rejectSend: rejected, unknownSend: unknown, rejectOpen: rejectOpen) }
            }
        }
        #endif
        _dependencies = State(initialValue: dependencies)
    }

    var body: some Scene {
        #if os(macOS)
        // One window/connection. Losing focus is not a disconnect on desktop.
        Window("Pi Studio", id: "session") {
            ProjectsContainer(dependencies: dependencies)
                .frame(minWidth: 480, minHeight: 500)
                .onDisappear { Task { await projects.disconnect() } }
        }
        .defaultSize(width: 700, height: 760)
        #else
        WindowGroup {
            ProjectsContainer(dependencies: dependencies)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await projects.disconnect() } }
                }
        }
        #endif
    }
}
