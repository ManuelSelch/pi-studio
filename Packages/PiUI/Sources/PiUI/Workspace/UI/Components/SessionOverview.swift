import SwiftUI

/// Open-session switching, shared by the iPhone sheet and the Mac popover. It is a view of the
/// workspace's open sessions, never a second session model: selecting shows, closing merely ends
/// the local view, and neither platform summarises how many sessions are running.
struct SessionOverview: View {
    let sessions: [OpenSessionPresentation]
    let newSessionPath: String?
    /// No session is selected, so the workspace is showing projects.
    let isBrowsing: Bool
    let onSelect: @MainActor (String) -> Void
    let onClose: @MainActor (String) -> Void
    let onNewSession: @MainActor (String) -> Void
    let onProjects: @MainActor () -> Void

    var body: some View {
        List {
            Section {
                overviewRow(identifier: "overviewProjects", title: "Projects & history",
                            systemImage: "folder", isSelected: isBrowsing, action: onProjects)
                if let newSessionPath {
                    overviewRow(identifier: "overviewNewSession", title: "New session",
                                systemImage: "plus.bubble", isSelected: false) {
                        onNewSession(newSessionPath)
                    }
                }
            }
            Section("Open sessions") {
                if sessions.isEmpty {
                    Text("No open sessions. Pick one under Projects & history, or start a new one.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("overviewEmpty")
                } else {
                    ForEach(sessions) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .accessibilityIdentifier("sessionOverview")
    }

    private func overviewRow(identifier: String, title: String, systemImage: String,
                            isSelected: Bool,
                            action: @escaping @MainActor () -> Void) -> some View {
        Button { action() } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage).font(.body).frame(width: 22)
                    .accessibilityHidden(true)
                Text(title).font(.body)
                Spacer(minLength: 0)
                if isSelected { Image(systemName: "checkmark").font(.footnote.weight(.semibold)) }
            }
            .frame(minHeight: overviewRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    /// A row reports its status semantically, so colour is never the only signal.
    private func sessionRow(_ session: OpenSessionPresentation) -> some View {
        HStack(spacing: 10) {
            Button { onSelect(session.id) } label: {
                HStack(spacing: 10) {
                    SessionActivityIndicator(activity: session.activity)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.title).font(.body).lineLimit(1).truncationMode(.middle)
                        Text(subtitle(session))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                    if session.unread && !session.isSelected {
                        Image(systemName: "circle.fill").font(.system(size: 6))
                            .foregroundStyle(.tint).accessibilityLabel("Unread")
                    }
                }
                .frame(minHeight: overviewRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(session.title)
            .accessibilityValue(accessibilityValue(session))
            .accessibilityIdentifier("overviewSession-\(session.id)")

            Button { onClose(session.id) } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    .frame(width: 32, height: overviewRowHeight).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .accessibilityLabel("Close \(session.title) view")
            .accessibilityIdentifier("overviewClose-\(session.id)")
        }
    }

    private func subtitle(_ session: OpenSessionPresentation) -> String {
        session.context.isEmpty ? session.activity?.label ?? "Idle" : session.context
    }

    private func accessibilityValue(_ session: OpenSessionPresentation) -> String {
        var parts = [session.context.isEmpty ? "No project" : session.context]
        if session.isSelected { parts.append("Selected") }
        parts.append(session.activity?.label ?? "Idle")
        if session.unread && !session.isSelected { parts.append("Unread") }
        return parts.joined(separator: ", ")
    }

    /// Touch targets stay at least 44 points on iPhone once the list insets are applied.
    private var overviewRowHeight: CGFloat { 48 }
}

/// A sheet wrapper so the phone can present the overview without a tab strip.
struct SessionOverviewSheet: View {
    let sessions: [OpenSessionPresentation]
    let newSessionPath: String?
    let isBrowsing: Bool
    let onSelect: @MainActor (String) -> Void
    let onClose: @MainActor (String) -> Void
    let onNewSession: @MainActor (String) -> Void
    let onProjects: @MainActor () -> Void
    let onDismiss: @MainActor () -> Void

    var body: some View {
        NavigationStack {
            SessionOverview(sessions: sessions, newSessionPath: newSessionPath, isBrowsing: isBrowsing,
                            onSelect: { onSelect($0); onDismiss() },
                            onClose: onClose,
                            onNewSession: { onNewSession($0); onDismiss() },
                            onProjects: { onProjects(); onDismiss() })
                .navigationTitle("Sessions")
                .inlineNavigationTitle()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onDismiss)
                            .accessibilityIdentifier("closeOverview")
                    }
                }
        }
    }
}

private extension View {
    /// Inline titles are iPhone-only; the same sheet must still compile on macOS.
    @ViewBuilder func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
