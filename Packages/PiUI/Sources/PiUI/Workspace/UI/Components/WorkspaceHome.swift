import SwiftUI

/// Home owns no catalogue or session lifecycle; the switcher receives values and callbacks.
struct WorkspaceHome: View {
    let presentation: WorkspacePresentation
    let actions: WorkspaceActions
    @FocusState private var homeSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)
            Text("Let's cook")
                .font(.largeTitle.weight(.semibold))
                .accessibilityIdentifier("homeGreeting")
                .padding(.bottom, 28)

            ZStack(alignment: .top) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search or start a conversation…", text: .constant(""))
                        .textFieldStyle(.plain).focused($homeSearchFocused)
                        .accessibilityLabel("Quick switcher")
                        .accessibilityIdentifier("quickSwitcher")
                    #if os(macOS)
                    Text("⌘ K").font(.caption).foregroundStyle(.tertiary)
                    #endif
                }
                .padding(.horizontal, 16).frame(height: 52)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                .onChange(of: homeSearchFocused) { _, focused in
                    if focused && !presentation.quickSwitcherOpen { actions.openQuickSwitcher() }
                }

                if presentation.quickSwitcherOpen {
                    QuickSwitcherContent(presentation: presentation, actions: actions)
                        .fixedSize(horizontal: false, vertical: true)
                        .zIndex(1)
                }
            }
            .frame(maxWidth: 560).frame(height: 52).zIndex(1)

            if let error = presentation.error {
                VStack(spacing: 10) {
                    Text(verbatim: error).font(.callout).foregroundStyle(.red)
                        .accessibilityIdentifier("homeConnectionError")
                    Button("Try again", action: actions.connection)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("homeRetryConnection")
                }.padding(.top, 20)
            } else if presentation.isBusy {
                ProgressView("Connecting…").padding(.top, 20)
            }
            Spacer(minLength: 48)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surface)
    }

    private var surface: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}
