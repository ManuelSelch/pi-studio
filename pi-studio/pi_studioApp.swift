import SwiftUI
import Flux
import FactoryKit
import PiUI

@main
struct pi_studioApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let arguments = ProcessInfo.processInfo.arguments
            let suiteIndex = arguments.firstIndex(of: "--ui-settings-suite")
            let suite = suiteIndex.flatMap { index in
                arguments.indices.contains(index + 1) ? arguments[index + 1] : nil
            }
            let suiteName = suite?.hasPrefix("PiStudio.UITests.") == true ? suite! : "PiStudio.UITests." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suiteName)!
            if arguments.contains("--ui-reset-settings") {
                defaults.removePersistentDomain(forName: suiteName)
            }
            let service = UserDefaultsEndpointSettingsService(defaults: defaults)
            Container.shared.endpointSettingsService.onDebug(factory: { service })
            
            
            let rejected = ProcessInfo.processInfo.arguments.contains("--ui-send-rejected")
            let unknown = ProcessInfo.processInfo.arguments.contains("--ui-send-unknown")
            let delayed = arguments.contains("--ui-send-delayed")
            Container.shared.makeConnection.onDebug(factory: { { _ in UITestConnection(rejectSend: rejected, unknownSend: unknown, delayedAdmission: delayed)} })
        }
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        // One window/connection. Losing focus is not a disconnect on desktop.
        Window("Pi Studio", id: "session") {
            SessionContainer()
                .frame(minWidth: 480, minHeight: 500)
                .onDisappear { Container.shared.sessionStore().dispatch(.disconnectRequested()) }
        }
        .defaultSize(width: 700, height: 760)
        #else
        WindowGroup {
            SessionContainer()
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Container.shared.sessionStore().dispatch(.disconnectRequested()) }
                }
        }
        #endif
    }
}
