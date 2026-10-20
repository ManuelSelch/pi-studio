import SwiftUI

struct ProjectList: View {
    let groups: [ProjectGroup]
    let canOpen: Bool
    let onOpen: @MainActor (ProjectSessionTarget, String) -> Void
    let onCreate: @MainActor (String) -> Void
    @State private var expanded: Set<String> = []
    @State private var collapsedQuickChats: Set<String> = []

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(groups) { group in
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Button {
                                if group.quickChats { toggle(group.id, in: &collapsedQuickChats) }
                                else { toggle(group.id, in: &expanded) }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: group.quickChats ? "bubble.left" : "folder")
                                        .foregroundStyle(.secondary).frame(width: 20)
                                    Text(group.name).font(.body.weight(.semibold))
                                    Spacer(minLength: 4)
                                    Image(systemName: isExpanded(group) ? "chevron.down" : "chevron.right")
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                                .frame(minHeight: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(group.name)
                            .accessibilityValue(isExpanded(group) ? "Expanded" : "Collapsed")
                            Button { onCreate(group.newSessionPath) } label: {
                                Image(systemName: "plus").frame(width: 44, height: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).foregroundStyle(.tint)
                            .disabled(!canOpen || !group.canCreate)
                            .accessibilityLabel(group.quickChats ? "New chat" : "New session in \(group.name)")
                            .accessibilityIdentifier("newSession-\(group.newSessionPath)")
                        }
                        if isExpanded(group) {
                            ForEach(group.sessions) { session in
                                Button { onOpen(session.target, session.title) } label: {
                                    HStack(spacing: 8) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(session.title).font(.subheadline).fontWeight(.regular)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            if let detail = session.detail {
                                                Text(detail).font(.caption2).foregroundStyle(.secondary)
                                            }
                                        }
                                        if let activity = session.activity {
                                            Text(activity).font(.caption2)
                                                .foregroundStyle(activity == "Running" ? .green : .secondary)
                                        }
                                    }
                                    .frame(minHeight: 44).padding(.leading, 28).padding(.trailing, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).disabled(!canOpen || !session.canOpen)
                                .accessibilityIdentifier("session-\(session.id)")
                            }
                            if group.sessions.isEmpty {
                                Text("No chats yet. Tap + to start one.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 28).padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    if group.quickChats { Divider().padding(.vertical, 4) }
                }
            }
            .padding(.top, 4)
        }
    }
    private func isExpanded(_ group: ProjectGroup) -> Bool {
        group.quickChats ? !collapsedQuickChats.contains(group.id) : expanded.contains(group.id)
    }
    private func toggle(_ id: String, in values: inout Set<String>) {
        if values.contains(id) { values.remove(id) } else { values.insert(id) }
    }
}
