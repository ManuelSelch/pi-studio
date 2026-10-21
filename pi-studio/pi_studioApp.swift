import SwiftUI
import Flux
import FactoryKit
import PiUI

@main
struct pi_studioApp: App {
    @State private var dependencies: SessionDependencies
    @Environment(\.scenePhase) private var scenePhase

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
                .onDisappear { dependencies.sessionStore().dispatch(.disconnectRequested()) }
        }
        .defaultSize(width: 700, height: 760)
        #else
        WindowGroup {
            SessionContainer(dependencies: dependencies, title: "Pi Pocket")
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { dependencies.sessionStore().dispatch(.disconnectRequested()) }
                }
        }
        #endif
    }
}
