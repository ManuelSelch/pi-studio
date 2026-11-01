import SwiftUI
import Flux
import FactoryKit
import PiUI

@main
struct pi_studioApp: App {
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["PI_UI_TESTING"] == "1" {
            let suite = environment["PI_UI_SETTINGS_SUITE"]
            let suiteName = suite?.hasPrefix("PiStudio.UITests.") == true ? suite! : "PiStudio.UITests." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suiteName)!
            if environment["PI_UI_RESET_SETTINGS"] == "1" {
                defaults.removePersistentDomain(forName: suiteName)
            }
            let service = UserDefaultsEndpointSettingsService(defaults: defaults)
            let laterService = UserDefaultsLaterSessionsService(defaults: defaults)
            Container.shared.endpointSettingsService.onDebug(factory: { service })
            Container.shared.laterSessionsService.onDebug(factory: { laterService })
            
            
            let rejected = environment["PI_UI_SEND_REJECTED"] == "1"
            let unknown = environment["PI_UI_SEND_UNKNOWN"] == "1"
            let delayed = environment["PI_UI_SEND_DELAYED"] == "1"
            let rejectOpen = environment["PI_UI_OPEN_REJECTED"] == "1"
            let markdown = environment["PI_UI_MARKDOWN_RESPONSE"] == "1"
            let connection = UITestConnection(rejectSend: rejected, unknownSend: unknown,
                                              rejectOpen: rejectOpen, delayedAdmission: delayed,
                                              markdownResponse: markdown)
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
