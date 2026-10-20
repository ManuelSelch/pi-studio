import SwiftUI
import Flux

/// The only view that knows about Flux and session dependencies. Routing belongs
/// to the host shell when navigation is introduced; components remain unaware.
public struct SessionContainer: View {
    private let controller: SessionController
    private let title: String
    @ObservedObject private var store: FluxStore<SessionFeature>

    public init(controller: SessionController, title: String = "Pi Studio") {
        self.controller = controller; self.title = title
        _store = ObservedObject(wrappedValue: controller.store)
    }

    public var body: some View {
        SessionScreen(
            presentation: presentation,
            onDraftChanged: controller.setDraft,
            onConnect: { Task { await controller.connect(takingControl: true) } },
            onDisconnect: { Task { await controller.disconnect() } },
            onSend: { Task { await controller.send() } },
            onStop: { Task { await controller.stop() } }
        )
    }

    private var presentation: SessionPresentation {
        let state = store.state
        var value = SessionPresentation()
        value.title = title
        value.status = state.statusText
        value.details = "\(controller.configuration.endpoint.absoluteString) · \(controller.configuration.projectPath)"
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
