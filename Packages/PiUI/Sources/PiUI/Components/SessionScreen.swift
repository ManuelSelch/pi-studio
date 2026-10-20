import SwiftUI

/// Plain presentation values: no Flux, router, SDK types or service lookups.
public struct SessionPresentation: Equatable, Sendable {
    public var title = "Pi Studio"
    public var status = "Disconnected"
    public var details = ""
    public var error: String?
    public var draft = ""
    public var hint = ""
    public var placeholder = "Your demo conversation will appear here."
    public var messages: [TranscriptMessage] = []
    public var canConnect = true
    public var canEditMessage = false
    public var canSend = false
    public var canStop = false
    public var requiresDisconnectWarning = false
    public init() {}
}

public struct SessionScreen: View {
    public let presentation: SessionPresentation
    public let showsHeader: Bool
    public let onDraftChanged: @MainActor (String) -> Void
    public let onConnect: @MainActor () -> Void
    public let onDisconnect: @MainActor () -> Void
    public let onSend: @MainActor () -> Void
    public let onStop: @MainActor () -> Void
    @State private var confirmConnect = false
    @State private var confirmDisconnect = false
    @FocusState private var messageFocused: Bool

    public init(presentation: SessionPresentation, showsHeader: Bool = true, onDraftChanged: @escaping @MainActor (String) -> Void,
                onConnect: @escaping @MainActor () -> Void, onDisconnect: @escaping @MainActor () -> Void,
                onSend: @escaping @MainActor () -> Void, onStop: @escaping @MainActor () -> Void) {
        self.showsHeader = showsHeader
        self.presentation = presentation; self.onDraftChanged = onDraftChanged
        self.onConnect = onConnect; self.onDisconnect = onDisconnect
        self.onSend = onSend; self.onStop = onStop
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                SessionHeader(title: presentation.title, status: presentation.status,
                              details: presentation.details, canConnect: presentation.canConnect) {
                    messageFocused = false
                    if presentation.canConnect { confirmConnect = true }
                    else if presentation.requiresDisconnectWarning { confirmDisconnect = true }
                    else { onDisconnect() }
                }
            }
            if let error = presentation.error {
                Text(verbatim: error)
                    .font(.subheadline).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal).padding(.bottom, 12)
                    .accessibilityIdentifier("errorMessage")
            }
            if showsHeader { Divider() }
            SessionTranscript(messages: presentation.messages, placeholder: presentation.placeholder)
            Divider()
            SessionComposer(draft: presentation.draft, hint: presentation.hint,
                            canEdit: presentation.canEditMessage, canSend: presentation.canSend,
                            canStop: presentation.canStop, focus: $messageFocused,
                            onDraftChanged: onDraftChanged,
                            onSend: { messageFocused = false; onSend() }, onStop: onStop)
        }
        .frame(maxWidth: 620, maxHeight: .infinity)
        .background(contentBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(outerBackground)
        .alert("Connect and take control?", isPresented: $confirmConnect) {
            Button("Cancel", role: .cancel) {}
            Button("Connect and take control", action: onConnect)
        } message: {
            Text("This replaces any current server controller and creates a fresh demo session. Existing server sessions are not closed.")
        }
        .alert("Disconnect?", isPresented: $confirmDisconnect) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive, action: onDisconnect)
        } message: {
            Text("Server work may continue. Disconnecting does not stop or close the session.")
        }
    }

    private var contentBackground: Color {
        #if os(macOS)
        Color(nsColor: .textBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
    private var outerBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}

#Preview {
    SessionScreen(presentation: .init(), onDraftChanged: { _ in }, onConnect: {}, onDisconnect: {}, onSend: {}, onStop: {})
}
