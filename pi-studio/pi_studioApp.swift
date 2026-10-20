import SwiftUI
import FactoryKit
import PiUI

@main
struct pi_studioApp: App {
    @State private var dependencies: SessionDependencies
    @Environment(\.scenePhase) private var scenePhase
    private var session: SessionController { dependencies.sessionController() }

    init() {
        let dependencies = SessionDependencies()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let rejected = ProcessInfo.processInfo.arguments.contains("--ui-send-rejected")
            let unknown = ProcessInfo.processInfo.arguments.contains("--ui-send-unknown")
            dependencies.makeConnection.register {
                { _ in UITestConnection(rejectSend: rejected, unknownSend: unknown) }
            }
        }
        #endif
        _dependencies = State(initialValue: dependencies)
    }

    var body: some Scene {
        #if os(macOS)
        // One window/connection. Losing focus is not a disconnect on desktop.
        Window("Pi Studio", id: "session") {
            SessionContainer(dependencies: dependencies)
                .frame(minWidth: 480, minHeight: 500)
                .onDisappear { Task { await session.disconnect() } }
        }
        .defaultSize(width: 700, height: 760)
        #else
        WindowGroup {
            SessionContainer(dependencies: dependencies, title: "Pi Pocket")
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await session.disconnect() } }
                }
        }
        #endif
    }
}
