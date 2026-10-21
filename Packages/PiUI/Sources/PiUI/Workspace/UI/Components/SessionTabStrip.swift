import SwiftUI

/// The horizontal open-session strip. One selected conversation is rendered below it;
/// selecting an overflowed tab scrolls it into view.
struct SessionTabStrip: View {
    let tabs: [SessionTabPresentation]
    let onSelect: @MainActor (String) -> Void
    let onClose: @MainActor (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(tabs) { tab in
                        SessionTab(tab: tab, onSelect: { onSelect(tab.id) }, onClose: { onClose(tab.id) })
                    }
                }
            }
            .onChange(of: tabs.first { $0.isSelected }?.id) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .center) }
            }
            .onAppear {
                guard let id = tabs.first(where: { $0.isSelected })?.id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
        }
        .frame(height: 40)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityIdentifier("sessionTabStrip")
    }
}

/// One tab: status, label, optional unread marker and a per-session close control.
/// Status is never colour-only, and closing only ends the local view.
struct SessionTab: View {
    let tab: SessionTabPresentation
    let onSelect: @MainActor () -> Void
    let onClose: @MainActor () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    SessionActivityIndicator(activity: tab.activity)
                    Text(tab.title).font(.caption).lineLimit(1).truncationMode(.middle)
                    if tab.unread && !tab.isSelected {
                        Image(systemName: "circle.fill").font(.system(size: 5)).foregroundStyle(.tint)
                            .accessibilityLabel("Unread")
                    }
                }
                .padding(.leading, 14).padding(.trailing, 8).padding(.vertical, 12)
                .frame(maxWidth: 205, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(tab.isSelected ? .primary : .secondary)
            .accessibilityLabel(tab.title)
            .accessibilityValue(tab.isSelected ? "Selected" : (tab.activity?.label ?? "Idle"))
            .accessibilityIdentifier("sessionTab-\(tab.id)")

            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                    .frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .padding(.trailing, 6)
            .accessibilityLabel("Close \(tab.title) view")
            .accessibilityIdentifier("closeSessionTab-\(tab.id)")
        }
        .background(tab.isSelected ? Color.primary.opacity(0.06) : .clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(tab.isSelected ? Color.primary.opacity(0.55) : .clear)
                .frame(height: 2).padding(.horizontal, 10)
        }
        .overlay(alignment: .trailing) { Divider() }
    }
}
