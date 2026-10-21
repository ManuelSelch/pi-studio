import SwiftUI
import Flux

/// Bridges the session and settings features through app composition. Routing belongs
/// to the host shell when navigation is introduced; components remain unaware.
public struct SessionContainer: View {
    private let projectPath: String
    private let title: String
    private let settings: SettingsController
    @ObservedObject private var settingsStore: FluxStore<SettingsFeature>
    @ObservedObject private var store: FluxStore<SessionFeature>

    public init(dependencies: SessionDependencies, title: String = "Pi Studio") {
        self.init(store: dependencies.sessionStore(), settings: dependencies.settingsController(),
                  projectPath: dependencies.sessionConfiguration().projectPath, title: title)
    }

    /// Explicit store injection remains useful for focused previews and tests.
    public init(store: FluxStore<SessionFeature>, settings: SettingsController,
                projectPath: String = SessionConfiguration.development.projectPath, title: String = "Pi Studio") {
        self.projectPath = projectPath; self.settings = settings; self.title = title
        _settingsStore = ObservedObject(wrappedValue: settings.store)
        _store = ObservedObject(wrappedValue: store)
    }

    public var body: some View {
        SessionScreen(
            presentation: presentation,
            onDraftChanged: { store.dispatch(.draftChanged($0)) },
            onConnect: { store.dispatch(.connectRequested(takingControl: true)) },
            onDisconnect: { store.dispatch(.disconnectRequested()) },
            onSend: { store.dispatch(.sendRequested()) },
            onStop: { store.dispatch(.stopRequested()) },
            onSettings: settings.open
        )
        .sheet(isPresented: Binding(
            get: { settingsStore.state.isPresented },
            set: { if !$0 { settings.cancel() } }
        )) {
            SettingsContainer(controller: settings)
        }
    }

    private var presentation: SessionPresentation {
        let state = store.state
        var value = SessionPresentation()
        value.title = title
        value.status = state.statusText
        let savedEndpoint = settingsStore.state.savedEndpoint
        let activeEndpoint = state.canConnect ? nil : state.connectionEndpoint?.absoluteString
        value.details = "\(activeEndpoint ?? savedEndpoint) · \(projectPath)"
        if let activeEndpoint, activeEndpoint != savedEndpoint {
            value.details += "\nNext connection: \(savedEndpoint)"
        }
        value.error = state.errorMessage
        value.draft = state.draft
        value.hint = state.hint
        value.canConnect = state.canConnect
        value.canEditMessage = state.canEditMessage
        value.canSend = state.canSend
        value.canStop = state.canStop
        value.requiresDisconnectWarning = state.requiresDisconnectWarning
        value.placeholder = state.connection == .connecting ? "Preparing the demo session…" : state.canEditMessage ? "Demo ready. Send a message to begin." : "Your demo conversation will appear here."
        value.messages = (state.projection?.messages ?? []).map { TranscriptMessage(id: $0.id, role: $0.role == "user" ? "You" : $0.role.capitalized, text: $0.text) }
        return value
    }
}
