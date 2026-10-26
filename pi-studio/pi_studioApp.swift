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
            
            
            let rejected = arguments.contains("--ui-send-rejected")
            let unknown = arguments.contains("--ui-send-unknown")
            let delayed = arguments.contains("--ui-send-delayed")
            let rejectOpen = arguments.contains("--ui-open-rejected")
            let connection = UITestConnection(rejectSend: rejected, unknownSend: unknown,
                                              rejectOpen: rejectOpen, delayedAdmission: delayed)
            Container.shared.makeSessionConnection.onDebug(factory: { { _ in connection } })
        }
        #endif
    }

    var body: some Scene {
        #if os(macOS)
        // One window/connection. Losing focus is not a disconnect on desktop.
        Window("Pi Studio", id: "workspace") {
            AppContainer()
                .frame(minWidth: 620, minHeight: 500)
                .onDisappear { Container.shared.workspaceStore().dispatch(.disconnectRequested()) }
        }
        .defaultSize(width: 980, height: 760)
        #else
        WindowGroup {
            AppContainer()
                .onChange(of: scenePhase) { _, phase in
                    // Backgrounding disposes local networking; server work keeps running.
                    if phase == .background { Container.shared.workspaceStore().dispatch(.disconnectRequested()) }
                }
        }
        #endif
    }
}
