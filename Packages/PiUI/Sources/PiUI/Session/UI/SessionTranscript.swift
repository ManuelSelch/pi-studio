import SwiftUI

public struct TranscriptMessage: Identifiable, Equatable, Sendable {
    public let id: String
    public let role: String
    public let text: String
    public init(id: String, role: String, text: String) {
        self.id = id; self.role = role; self.text = text
    }
}

struct SessionTranscript: View {
    let messages: [TranscriptMessage]
    let placeholder: String
    let followTail: Bool
    let anchor: String?
    let onFollowTailChanged: @MainActor (Bool) -> Void
    let onAnchorChanged: @MainActor (String?) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if messages.isEmpty {
                        Text(placeholder).font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 200).multilineTextAlignment(.center)
                    }
                    ForEach(messages) { message in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(message.role).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(verbatim: message.text).textSelection(.enabled)
                                .accessibilityIdentifier("message-\(message.id)")
                        }
                        .id(message.id)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            // A followed tail keeps moving; reading older text never gets yanked away.
            .onChange(of: messages.last?.id) { _, id in
                onAnchorChanged(id)
                guard followTail else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: followTail) { _, following in
                guard following else { return }
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.containerSize.height >= geometry.contentSize.height - 24
            } action: { _, atBottom in
                onFollowTailChanged(atBottom)
            }
            .onAppear { restore(proxy) }
        }
    }

    /// Re-entering a session restores its own reading position.
    private func restore(_ proxy: ScrollViewProxy) {
        if followTail { proxy.scrollTo("bottom", anchor: .bottom) }
        else if let anchor { proxy.scrollTo(anchor, anchor: .top) }
    }
}
