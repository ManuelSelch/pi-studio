import SwiftUI

/// Compact project, Quick Chats and history navigation. Layout and disclosure
/// state only: every action is a callback, and all data is plain presentation.
struct WorkspaceSidebar: View {
    let presentation: WorkspacePresentation
    let onOpen: @MainActor (ProjectSessionTarget, String) -> Void
    let onCreate: @MainActor (String) -> Void
    /// One connection action: the container owns consent confirmation so the
    /// sidebar and the empty state cannot disagree about it.
    let onConnection: @MainActor () -> Void
    let onSettings: @MainActor () -> Void
    @State private var expanded: Set<String> = []
    @State private var collapsedQuickChats: Set<String> = []
    @State private var search = ""

    var body: some View {
        VStack(spacing: 0) {
            searchField
            if let error = presentation.error {
                Text(verbatim: error)
                    .font(.caption).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 6)
                    .accessibilityIdentifier("errorMessage")
            }
            Divider()
            ScrollView {
                LazyVStack(spacing: 2) {
                    if let quickChats = presentation.quickChats, isVisible(quickChats) {
                        group(quickChats)
                        Divider().padding(.vertical, 4)
                    }
                    if hasProjects {
                        sectionLabel("Projects & history")
                        ForEach(visibleProjects) { group($0) }
                    }
                }
                .padding(.vertical, 4)
            }
            Divider()
            footer
        }
    }

    // MARK: - Pieces

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.caption).foregroundStyle(.secondary)
            TextField("Search sessions", text: $search)
                .textFieldStyle(.plain).font(.subheadline)
                .accessibilityLabel("Search sessions")
                .accessibilityIdentifier("sessionSearch")
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 32)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold)).textCase(.uppercase).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 2)
    }

    @ViewBuilder private func group(_ value: ProjectGroup) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button { toggle(value) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isExpanded(value) ? "chevron.down" : "chevron.right")
                            .font(.caption2).foregroundStyle(.tertiary).frame(width: 10)
                        Image(systemName: value.quickChats ? "bubble.left" : "folder")
                            .font(.caption).foregroundStyle(.secondary).frame(width: 16)
                        Text(value.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value.name)
                .accessibilityValue(isExpanded(value) ? "Expanded" : "Collapsed")
                Button { onCreate(value.newSessionPath) } label: {
                    Image(systemName: "plus").frame(width: 40, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(.tint)
                .disabled(!presentation.canOpen || !value.canCreate)
                .accessibilityLabel(value.quickChats ? "New chat" : "New session in \(value.name)")
                .accessibilityIdentifier("newSession-\(value.newSessionPath)")
            }
            .padding(.horizontal, 10)
            if isExpanded(value) {
                ForEach(visibleSessions(in: value)) { row($0) }
                if value.sessions.isEmpty {
                    Text(value.quickChats ? "No chats yet." : "No sessions yet.")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 36).padding(.vertical, 6)
                }
            }
        }
    }

    @ViewBuilder private func row(_ value: ProjectSessionRow) -> some View {
        Button { onOpen(value.target, value.title) } label: {
            HStack(spacing: 8) {
                SessionActivityIndicator(activity: value.activity)
                VStack(alignment: .leading, spacing: 1) {
                    Text(value.title).font(.subheadline).lineLimit(1)
                    if let detail = value.detail {
                        Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let activity = value.activity {
                    Text(activity.label).font(.caption2).foregroundStyle(activity.tint)
                }
            }
            .padding(.leading, 36).padding(.trailing, 10)
            .frame(minHeight: 40)
            .background(isSelected(value) ? Color.accentColor.opacity(0.15) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!presentation.canOpen || !value.canOpen)
        .accessibilityIdentifier("session-\(value.id)")
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle().fill(presentation.canConnect ? Color.secondary : Color.green).frame(width: 8, height: 8)
            Text(presentation.status).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                .accessibilityIdentifier("connectionStatus")
            Spacer(minLength: 4)
            Button(action: onConnection) {
                Image(systemName: presentation.canConnect ? "bolt" : "bolt.slash").frame(width: 32, height: 40)
            }
            .buttonStyle(.plain).foregroundStyle(.tint)
            .accessibilityLabel(presentation.canConnect ? "Connect" : "Disconnect")
            .accessibilityIdentifier("connectButton")
            Button(action: onSettings) {
                Image(systemName: "gearshape").frame(width: 32, height: 40)
            }
            .buttonStyle(.plain).foregroundStyle(.tint)
            .accessibilityLabel("Connection settings")
            .accessibilityIdentifier("settingsButton")
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Disclosure and filtering

    private func toggle(_ value: ProjectGroup) {
        if value.quickChats {
            if collapsedQuickChats.contains(value.id) { collapsedQuickChats.remove(value.id) }
            else { collapsedQuickChats.insert(value.id) }
        } else if expanded.contains(value.id) { expanded.remove(value.id) }
        else { expanded.insert(value.id) }
    }

    private func isExpanded(_ value: ProjectGroup) -> Bool {
        if value.quickChats { return !collapsedQuickChats.contains(value.id) }
        return !search.isEmpty || expanded.contains(value.id)
    }

    private func isVisible(_ value: ProjectGroup) -> Bool {
        search.isEmpty || value.name.localizedCaseInsensitiveContains(search)
            || value.sessions.contains { matches($0) }
    }

    private func visibleSessions(in value: ProjectGroup) -> [ProjectSessionRow] {
        search.isEmpty ? value.sessions : value.sessions.filter(matches)
    }

    private func matches(_ value: ProjectSessionRow) -> Bool {
        value.title.localizedCaseInsensitiveContains(search) || (value.detail?.localizedCaseInsensitiveContains(search) ?? false)
    }

    private var visibleProjects: [ProjectGroup] {
        search.isEmpty ? presentation.projects : presentation.projects.filter(isVisible)
    }

    private var hasProjects: Bool { !visibleProjects.isEmpty }

    private func isSelected(_ value: ProjectSessionRow) -> Bool { value.target == presentation.selection?.target }
}
