import SwiftUI
import PiUI

@main
struct pi_studioApp: App {
    @State private var session: SessionController
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let rejected = ProcessInfo.processInfo.arguments.contains("--ui-send-rejected")
            let unknown = ProcessInfo.processInfo.arguments.contains("--ui-send-unknown")
            _session = State(initialValue: SessionController(makeConnection: { _ in
                UITestConnection(rejectSend: rejected, unknownSend: unknown)
            }))
            return
        }
        #endif
        _session = State(initialValue: SessionController())
    }

    var body: some Scene {
        #if os(macOS)
        // One window/connection. Losing focus is not a disconnect on desktop.
        Window("Pi Studio", id: "session") {
            SessionContainer(controller: session)
                .frame(minWidth: 480, minHeight: 500)
                .onDisappear { Task { await session.disconnect() } }
        }
        .defaultSize(width: 700, height: 760)
        #else
        WindowGroup {
            SessionContainer(controller: session, title: "Pi Pocket")
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await session.disconnect() } }
                }
        }
        #endif
    }
}
