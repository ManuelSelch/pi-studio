import SwiftUI

/// iPhone navigation: projects are the root list and the conversation is pushed. There is no
/// tab strip; open sessions are switched through the overview sheet.
struct PhoneWorkspaceScreen: View {
    let presentation: WorkspacePresentation
    let session: SessionPresentation
    let actions: WorkspaceActions
    @State private var showsOverview = false
    @State private var showsProjects = false

    var body: some View {
        NavigationStack {
            WorkspaceHome(presentation: presentation, actions: actions)
                .navigationTitle("Pi Studio")
                .phoneTitleDisplayMode()
                .phoneHomeToolbar(openProjects: { showsProjects = true }, openSettings: actions.settings,
                                   isConnected: presentation.isConnected,
                                   openOverview: { showsOverview = true })
                .navigationDestination(isPresented: showsConversation) { conversation }
        }
        .sheet(isPresented: $showsProjects) { sidebar }
            .onChange(of: presentation.selection) { _, selection in
                if selection != nil { showsProjects = false }
            }
        .sheet(isPresented: $showsOverview) {
            SessionOverviewSheet(sessions: presentation.openSessions,
                                 newSessionPath: presentation.newSessionPath,
                                 isBrowsing: presentation.selection == nil,
                                 onSelect: actions.selectTab,
                                 onClose: actions.closeTab,
                                 onNewSession: actions.create,
                                 onProjects: actions.back,
                                 onDismiss: { showsOverview = false })
                .presentationDetents([.medium, .large])
        }
    }

    private var sidebar: some View {
        WorkspaceSidebar(presentation: presentation, onOpen: actions.open, onCreate: actions.create,
                         onMoveToLater: actions.moveToLater,
                         onConnection: actions.connection, onSettings: actions.settings)
    }

    /// The store stays authoritative: dismissing the pushed view deselects there.
    private var showsConversation: Binding<Bool> {
        Binding(get: { presentation.selection != nil },
                set: { presented in if !presented { actions.back() } })
    }

    @ViewBuilder private var conversation: some View {
        if let selection = presentation.selection {
            WorkspaceConversation(selection: selection, session: session,
                                  onDraftChanged: actions.draftChanged, onSend: actions.send, onStop: actions.stop,
                                  onFollowTailChanged: actions.followTailChanged,
                                  onScrollAnchorChanged: actions.scrollAnchorChanged)
                .phoneConnectionToolbar(connection: actions.connection, settings: actions.settings,
                                       openOverview: { showsOverview = true }, openQuickSwitcher: actions.openQuickSwitcher)
        } else {
            WorkspaceHome(presentation: presentation, actions: actions)
        }
    }
}

private extension View {
    /// The project navigator remains the existing sidebar, presented separately on iPhone.
    @ViewBuilder func phoneHomeToolbar(openProjects: @escaping @MainActor () -> Void,
                                        openSettings: @escaping @MainActor () -> Void,
                                        isConnected: Bool,
                                        openOverview: @escaping @MainActor () -> Void) -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: openProjects) { Image(systemName: "line.3.horizontal") }
                    .accessibilityLabel("Projects")
                    .accessibilityIdentifier("projectsButton")
            }
            if isConnected {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openOverview) { Image(systemName: "rectangle.stack") }
                        .accessibilityLabel("Open sessions")
                        .accessibilityIdentifier("sessionsButton")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openSettings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("Connection settings")
                    .accessibilityIdentifier("settingsButton")
            }
        }
        #else
        self
        #endif
    }

    /// Inline titles are iPhone-only; the same screen must still compile on macOS.
    @ViewBuilder func phoneTitleDisplayMode() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// A pushed conversation must still reach connection settings on iPhone, where
    /// the sidebar footer is off screen.
    @ViewBuilder func phoneConnectionToolbar(connection: @escaping @MainActor () -> Void,
                                            settings: @escaping @MainActor () -> Void,
                                            openOverview: @escaping @MainActor () -> Void,
                                            openQuickSwitcher: @escaping @MainActor () -> Void) -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openQuickSwitcher) { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel("Quick switcher")
                    .accessibilityIdentifier("openQuickSwitcher")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openOverview) { Image(systemName: "rectangle.stack") }
                    .accessibilityLabel("Open sessions")
                    .accessibilityIdentifier("sessionsButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: settings) { Image(systemName: "gearshape") }
                    .accessibilityLabel("Connection settings")
                    .accessibilityIdentifier("settingsButton")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: connection) { Image(systemName: "bolt.slash") }
                    .accessibilityLabel("Disconnect")
                    .accessibilityIdentifier("connectButton")
            }
        }
        #else
        self
        #endif
    }
}
