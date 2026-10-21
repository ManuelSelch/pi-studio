import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Plain presentation values: no Flux, router, SDK types or service lookups.
public struct SessionPresentation: Equatable, Sendable {
    public var title = "Pi Studio"
    public var status = "Disconnected"
    public var details = ""
    public var error: String?
    /// The selected tab's draft: the workspace owns it, the composer only edits it.
    public var draft = ""
    /// Why the composer is locked right now, if it is.
    public var hint = ""
    /// Auto-scroll policy and reading position of the selected tab.
    public var followTail = true
    public var scrollAnchor: String?
    public var placeholder = "Your demo conversation will appear here."
    public var messages: [TranscriptMessage] = []
    public var canConnect = true
    public var canEditMessage = false
    public var canSend = false
    public var canStop = false
    public var isStopping = false
    public var requiresDisconnectWarning = false
    public init() {}
}

public struct SessionScreen: View {
    public let presentation: SessionPresentation
    public let onDraftChanged: @MainActor (String) -> Void
    public let onConnect: @MainActor () -> Void
    public let onDisconnect: @MainActor () -> Void
    public let onSend: @MainActor (String) -> Void
    public let onStop: @MainActor () -> Void
    public let onSettings: @MainActor () -> Void
    public let onFollowTailChanged: @MainActor (Bool) -> Void
    public let onScrollAnchorChanged: @MainActor (String?) -> Void
    /// A workspace shell supplies its own navigation and connection controls, so the standalone
    /// header is omitted there while the conversation stays identical.
    private let showsHeader: Bool
    private let maxContentWidth: CGFloat
    @State private var confirmConnect = false
    @State private var confirmDisconnect = false
    @FocusState private var messageFocused: Bool

    public init(presentation: SessionPresentation,
                onDraftChanged: @escaping @MainActor (String) -> Void,
                onConnect: @escaping @MainActor () -> Void, onDisconnect: @escaping @MainActor () -> Void,
                onSend: @escaping @MainActor (String) -> Void, onStop: @escaping @MainActor () -> Void,
                onSettings: @escaping @MainActor () -> Void = {},
                onFollowTailChanged: @escaping @MainActor (Bool) -> Void = { _ in },
                onScrollAnchorChanged: @escaping @MainActor (String?) -> Void = { _ in },
                showsHeader: Bool = true, maxContentWidth: CGFloat = 620) {
        self.presentation = presentation
        self.onDraftChanged = onDraftChanged
        self.onConnect = onConnect; self.onDisconnect = onDisconnect
        self.onSend = onSend; self.onStop = onStop; self.onSettings = onSettings
        self.onFollowTailChanged = onFollowTailChanged
        self.onScrollAnchorChanged = onScrollAnchorChanged
        self.showsHeader = showsHeader; self.maxContentWidth = maxContentWidth
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showsHeader {
                SessionHeader(title: presentation.title, status: presentation.status,
                              details: presentation.details, canConnect: presentation.canConnect,
                              onSettings: { messageFocused = false; onSettings() }) {
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
            Divider()
            SessionTranscript(messages: presentation.messages, placeholder: presentation.placeholder,
                              followTail: presentation.followTail, anchor: presentation.scrollAnchor,
                              onFollowTailChanged: onFollowTailChanged,
                              onAnchorChanged: onScrollAnchorChanged)
            Divider()
            SessionComposer(draft: presentation.draft, hint: presentation.hint,
                            canEdit: presentation.canEditMessage, canSend: presentation.canSend,
                            canStop: presentation.canStop, isStopping: presentation.isStopping, focus: $messageFocused,
                            onDraftChanged: onDraftChanged,
                            onSend: { text in messageFocused = false; onSend(text) }, onStop: onStop)
        }
        #if os(macOS)
        .onExitCommand {
            // Fallback for focus elsewhere on the conversation. A sheet owns its own
            // Escape handling; the container also withholds canStop while settings is open.
            let event = NSApp.currentEvent
            let modifiers = event?.modifierFlags.intersection([.shift, .command, .option, .control]) ?? []
            let composing = (NSApp.keyWindow?.firstResponder as? NSTextView)?.hasMarkedText() == true
            if !confirmConnect && !confirmDisconnect && presentation.canStop,
               !composing, event?.isARepeat != true, modifiers.isEmpty { onStop() }
        }
        #endif
        .frame(maxWidth: maxContentWidth, maxHeight: .infinity)
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
    SessionScreen(presentation: .init(), onDraftChanged: { _ in }, onConnect: {}, onDisconnect: {}, onSend: { _ in }, onStop: {})
}
