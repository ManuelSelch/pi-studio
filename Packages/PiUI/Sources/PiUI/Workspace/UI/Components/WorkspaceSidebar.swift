import SwiftUI

/// Session inbox navigation. Status comes from the server catalogue; Later is explicit local intent.
struct WorkspaceSidebar: View {
    let presentation: WorkspacePresentation
    let onOpen: @MainActor (ProjectSessionTarget, String) -> Void
    let onCreate: @MainActor (String) -> Void
    let onMoveToLater: @MainActor (String) -> Void
    let onConnection: @MainActor () -> Void
    let onSettings: @MainActor () -> Void
    @State private var runningExpanded = true
    @State private var laterExpanded = false
    @State private var hoveredSession: String?
    @FocusState private var focusedLaterSession: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let error = presentation.error {
                Text(verbatim: error)
                    .font(.caption).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 6)
                    .accessibilityIdentifier("errorMessage")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    statusSection("Needs you", status: .needsYou)
                    statusSection("Ready", status: .ready)
                    if !presentation.sessions(in: .running).isEmpty {
                        VStack(spacing: 0) {
                            disclosure("Running", count: presentation.sessions(in: .running).count,
                                       expanded: $runningExpanded)
                            if runningExpanded { sessionRows(presentation.sessions(in: .running)) }
                        }
                    }
                    Spacer(minLength: 12)
                }
                .padding(.vertical, 8)
            }
            if !presentation.sessions(in: .later).isEmpty {
                Divider()
                VStack(spacing: 0) {
                    disclosure("Later", count: presentation.sessions(in: .later).count,
                               expanded: $laterExpanded)
                    if laterExpanded { sessionRows(presentation.sessions(in: .later)) }
                }
                .padding(.vertical, 6)
            }
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pi Studio").font(.caption).foregroundStyle(.secondary)
                Text("Sessions").font(.headline)
            }
            Spacer()
            Button {
                if let path = presentation.newSessionPath { onCreate(path) }
            } label: { Image(systemName: "plus").frame(width: 36, height: 40) }
                .buttonStyle(.plain).disabled(!presentation.canOpen || presentation.newSessionPath == nil)
                .accessibilityLabel("New session")
                .accessibilityIdentifier("newInboxSession")
        }
        .padding(.horizontal, 12).frame(minHeight: 54)
    }

    @ViewBuilder private func statusSection(_ title: String, status: InboxSession.Status) -> some View {
        let sessions = presentation.sessions(in: status)
        if !sessions.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                sessionRows(sessions)
            }
        }
    }

    private func disclosure(_ title: String, count: Int, expanded: Binding<Bool>) -> some View {
        Button { expanded.wrappedValue.toggle() } label: {
            HStack(spacing: 7) {
                Image(systemName: expanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(.caption2).foregroundStyle(.tertiary).frame(width: 10)
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Text("\(count)").font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(minHeight: 34).contentShape(Rectangle()).padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("inboxToggle-\(title.lowercased().replacingOccurrences(of: " ", with: ""))")
    }

    private func sessionRows(_ sessions: [InboxSession]) -> some View {
        ForEach(sessions) { session in
            HStack(spacing: 0) {
                Button { onOpen(session.row.target, session.row.title) } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 7) {
                            SessionActivityIndicator(activity: session.row.activity)
                            Text(session.displayLines[0]).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                        ForEach(Array(session.displayLines.dropFirst().enumerated()), id: \.offset) { _, line in
                            Text(line).font(.subheadline).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 10).padding(.trailing, 4).frame(minHeight: 46)
                    .background(isSelected(session.row) ? Color.accentColor.opacity(0.15) : .clear,
                                in: RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!presentation.canOpen || !session.row.canOpen)
                .accessibilityIdentifier("inbox-\(session.id)")
                if session.canMoveLater {
                    Button { if let path = session.row.sessionPath { onMoveToLater(path) } } label: {
                        Image(systemName: "clock.arrow.circlepath").frame(width: 34, height: 42)
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .accessibilityLabel("Move \(session.row.title) to Later")
                    .accessibilityIdentifier("moveLater-\(session.id)")
                    .focused($focusedLaterSession, equals: session.id)
                    .opacity(laterActionVisible(session.id) ? 1 : 0)
                } else if session.status == .later {
                    Button { onOpen(session.row.target, session.row.title) } label: {
                        Text("Resume").font(.caption).frame(minWidth: 46, minHeight: 42)
                    }
                    .buttonStyle(.plain).foregroundStyle(.tint)
                    .disabled(!presentation.canOpen || !session.row.canOpen)
                    .accessibilityIdentifier("resumeLater-\(session.id)")
                }
            }
            .onHover { hovering in
                if hovering { hoveredSession = session.id }
                else if hoveredSession == session.id { hoveredSession = nil }
            }
            .padding(.horizontal, 6)
            .background(isSelected(session.row) ? Color.accentColor.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
        }
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

    private func laterActionVisible(_ id: String) -> Bool {
        #if os(macOS)
        hoveredSession == id || focusedLaterSession == id
        #else
        true
        #endif
    }

    private func isSelected(_ row: ProjectSessionRow) -> Bool {
        presentation.selection?.represents(row) == true
    }
}
