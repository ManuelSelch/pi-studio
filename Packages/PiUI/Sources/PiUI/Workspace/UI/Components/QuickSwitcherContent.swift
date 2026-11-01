import SwiftUI

/// Shared search controls and results, independent of presentation and catalogue ownership.
struct QuickSwitcherContent: View {
    let presentation: WorkspacePresentation
    let actions: WorkspaceActions
    @State private var selected = 0
    @FocusState private var searchFocused: Bool

    private let scopes: [(String, String)] = [("All", ""), ("Folders", "#"), ("Worktrees", "%"), ("Sessions", "@"), ("Actions", "/")]
    private var prefix: String {
        let first = String(presentation.quickSwitcherQuery.prefix(1))
        return scopes.contains { !$0.1.isEmpty && $0.1 == first } ? first : ""
    }
    private var items: [QuickSwitcherModel.Item] { presentation.quickSwitcherItems }
    private var safeSelected: Int { min(selected, max(0, items.count - 1)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search folders, worktrees, sessions and actions…", text: Binding(
                    get: { presentation.quickSwitcherQuery },
                    set: { selected = 0; actions.quickSwitcherQueryChanged($0) }))
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .accessibilityLabel("Search folders, worktrees, sessions and actions")
                    .accessibilityIdentifier("quickSwitcherSearch")
                    .onSubmit { chooseSelected() }
                    #if os(macOS)
                    .onKeyPress(.downArrow) { moveSelection(1); return .handled }
                    .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
                    .onKeyPress(.tab, phases: .down) { press in cycleScope(press.modifiers.contains(.shift) ? -1 : 1); return .handled }
                    #endif
                Button("esc", action: actions.dismissQuickSwitcher)
                    .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel("Close quick switcher")
                    .accessibilityIdentifier("quickSwitcherDismiss")
            }
            .padding(.horizontal, 16).frame(height: 52)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(scopes, id: \.0) { scope in
                        Button(scope.1.isEmpty ? scope.0 : "\(scope.1) \(scope.0)") {
                            selected = 0; actions.quickSwitcherQueryChanged(scope.1); searchFocused = true
                        }
                        .buttonStyle(.plain).font(.caption.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(prefix == scope.1 ? Color.accentColor.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityIdentifier("quickSwitcherFilter-\(scope.0)")
                    }
                }.padding(.horizontal, 12).padding(.bottom, 10)
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text(prefix.isEmpty && presentation.quickSwitcherQuery.isEmpty ? "RECENT SESSIONS" : "RESULTS")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.top, 12)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            if items.isEmpty {
                                Text(prefix == "/" ? "No actions available yet." : "No matching results.")
                                    .font(.callout).foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                    .accessibilityIdentifier("quickSwitcherEmpty")
                            }
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                Button { actions.chooseQuickSwitcherItem(item) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: icon(for: item.kind)).foregroundStyle(.secondary).frame(width: 20)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.title).font(.callout.weight(.medium)).lineLimit(1)
                                            Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                    }.padding(.horizontal, 12).padding(.vertical, 9).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).disabled(!item.enabled)
                                .background(index == safeSelected ? Color.accentColor.opacity(0.1) : .clear,
                                            in: RoundedRectangle(cornerRadius: 8))
                                .accessibilityIdentifier("quickSwitcherResult-\(item.id)")
                                .id(item.id)
                            }
                        }.padding(.horizontal, 8)
                    }
                    .frame(maxHeight: 280)
                    .onChange(of: safeSelected) { _, index in
                        if items.indices.contains(index) { proxy.scrollTo(items[index].id) }
                    }
                }
            }.padding(.bottom, 8)
            Divider()
            HStack {
                Text("Tab filters · ↑↓ navigate · Enter open · Esc close")
                Spacer(minLength: 0)
            }.font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .onAppear { searchFocused = true }
        #if os(macOS)
        .onExitCommand { actions.dismissQuickSwitcher() }
        #endif
    }

    private func chooseSelected() {
        guard items.indices.contains(safeSelected), items[safeSelected].enabled else { return }
        actions.chooseQuickSwitcherItem(items[safeSelected])
    }

    private func moveSelection(_ step: Int) {
        guard !items.isEmpty else { return }
        for offset in 1...items.count {
            let index = (safeSelected + step * offset + items.count * 2) % items.count
            if items[index].enabled { selected = index; return }
        }
    }

    private func cycleScope(_ step: Int) {
        let index = scopes.firstIndex { $0.1 == prefix } ?? 0
        let text = prefix.isEmpty ? presentation.quickSwitcherQuery : String(presentation.quickSwitcherQuery.dropFirst())
        actions.quickSwitcherQueryChanged(scopes[(index + step + scopes.count) % scopes.count].1 + text)
        selected = 0
    }

    private func icon(for kind: QuickSwitcherModel.Kind) -> String {
        switch kind {
        case .folder: "folder"
        case .worktree: "point.topleft.down.to.point.bottomright.curvepath"
        case .session: "bubble.left"
        case .action: "bolt"
        }
    }
}

struct QuickSwitcherDialog: View {
    let presentation: WorkspacePresentation
    let actions: WorkspaceActions

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.25).ignoresSafeArea().onTapGesture { actions.dismissQuickSwitcher() }
            QuickSwitcherContent(presentation: presentation, actions: actions)
                .frame(maxWidth: 610).padding(.horizontal, 16).padding(.top, 60)
        }
    }
}
