import SwiftUI

/// Empty-workspace landing screen. It receives presentation values and callbacks only.
struct WorkspaceHome: View {
    let presentation: WorkspacePresentation
    let onRetry: @MainActor () -> Void

    @State private var quickSwitcherText = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 48)
            VStack(spacing: 10) {
                Text(greeting)
                    .font(.largeTitle.weight(.semibold))
                    .accessibilityIdentifier("homeGreeting")
                Text("Pick up where you left off, or start something new.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 28)

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or start a conversation…", text: $quickSwitcherText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Quick switcher")
                    .accessibilityIdentifier("quickSwitcher")
                #if os(macOS)
                Text("⌘ K").font(.caption).foregroundStyle(.tertiary)
                #endif
            }
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            .frame(maxWidth: 560)

            if let error = presentation.error {
                VStack(spacing: 10) {
                    Text(verbatim: error).font(.callout).foregroundStyle(.red)
                        .accessibilityIdentifier("homeConnectionError")
                    Button("Try again", action: onRetry)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("homeRetryConnection")
                }
                .padding(.top, 20)
            } else if presentation.isBusy {
                ProgressView("Connecting…").padding(.top, 20)
            }
            Spacer(minLength: 48)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(surface)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let salutation = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        return "\(salutation), Manuel"
    }

    private var surface: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }
}
