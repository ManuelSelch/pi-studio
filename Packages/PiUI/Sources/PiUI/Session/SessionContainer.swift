import SwiftUI
import Flux
import FactoryKit

/// Bridges the session and settings features through app composition. Routing belongs
/// to the host shell when navigation is introduced; components remain unaware.
public struct SessionContainer: View {
    @Injected(\.settingsStore) var settings
    @Injected(\.sessionStore) var store
    
    public init() {}

    public var body: some View {
        SessionScreen(
            presentation: presentation,
            onClearDraftConsumed: { store.dispatch(.clearDraftConsumed) },
            onConnect: { store.dispatch(.connectRequested(takingControl: true)) },
            onDisconnect: { store.dispatch(.disconnectRequested()) },
            onSend: { store.dispatch(.sendRequested(text: $0)) },
            onStop: { store.dispatch(.stopRequested()) },
            onSettings: { settings.dispatch(.opened) }
        )
        .sheet(isPresented: Binding(
            get: { settings.state.isPresented },
            set: { if !$0 { settings.dispatch(.cancelled) } }
        )) {
            SettingsContainer()
        }
    }

    private var presentation: SessionPresentation {
        let state = store.state
        var value = SessionPresentation()
        value.title = "Pi"
        value.status = state.statusText
        let savedEndpoint = settings.state.savedEndpoint
        let activeEndpoint = state.canConnect ? nil : state.connectionEndpoint?.absoluteString
        value.details = "\(activeEndpoint ?? savedEndpoint)"
        if let activeEndpoint, activeEndpoint != savedEndpoint {
            value.details += "\nNext connection: \(savedEndpoint)"
        }
        value.error = state.errorMessage
        value.clearDraftMatching = state.clearDraftMatching
        value.canConnect = state.canConnect
        value.canEditMessage = state.canEditMessage
        value.canSend = state.canSend
        value.canStop = state.canStop && !settings.state.isPresented
        value.isStopping = state.isStopping || state.projection?.status == .aborting
        value.requiresDisconnectWarning = state.requiresDisconnectWarning
        value.placeholder = state.connection == .connecting ? "Preparing the demo session…" : state.canEditMessage ? "Demo ready. Send a message to begin." : "Your demo conversation will appear here."
        value.messages = (state.projection?.messages ?? []).map { TranscriptMessage(id: $0.id, role: $0.role == "user" ? "You" : $0.role.capitalized, text: $0.text) }
        return value
    }
}
