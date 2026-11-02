import SwiftUI

public struct TranscriptMessage: Identifiable, Equatable, Sendable {
    public let id: String
    public let role: String
    public let text: String
    public init(id: String, role: String, text: String) {
        self.id = id; self.role = role; self.text = text
    }
}

enum TranscriptPresentation {
    static func labels(for messages: [TranscriptMessage]) -> [String?] {
        var hasAssistant = false
        return messages.map { message in
            if message.role == "You" {
                hasAssistant = false
                return "You"
            }
            if message.role == "Assistant" || message.role == "Agent" {
                guard !hasAssistant else { return nil }
                hasAssistant = true
                return "π"
            }
            return message.role
        }
    }
}

struct SessionTranscript: View {
    let messages: [TranscriptMessage]
    let isWorking: Bool
    let placeholder: String
    let followTail: Bool
    let anchor: String?
    let onFollowTailChanged: @MainActor (Bool) -> Void
    let onAnchorChanged: @MainActor (String?) -> Void

    var body: some View {
        let labels = TranscriptPresentation.labels(for: messages)
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if messages.isEmpty && !isWorking {
                        Text(placeholder).font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 200).multilineTextAlignment(.center)
                    }
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        VStack(alignment: .leading, spacing: 5) {
                            if let label = labels[index] {
                                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                                    .accessibilityIdentifier("role-\(message.id)")
                            }
                            MarkdownMessageView(text: message.text, preservePromptWhitespace: message.role == "You")
                                .textSelection(.enabled)
                                .accessibilityIdentifier("message-\(message.id)")
                        }
                        .id(message.id)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if isWorking {
                        VStack(alignment: .leading, spacing: 8) {
                            if !hasAssistantInCurrentTurn {
                                Text("π").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("Working…").font(.caption).foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("workingIndicator")
                        }
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
            .onChange(of: isWorking) { _, working in
                guard working && followTail else { return }
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

    private var hasAssistantInCurrentTurn: Bool {
        messages.reversed().prefix { $0.role != "You" }.contains { $0.role == "Assistant" || $0.role == "Agent" }
    }

    /// Re-entering a session restores its own reading position.
    private func restore(_ proxy: ScrollViewProxy) {
        if followTail { proxy.scrollTo("bottom", anchor: .bottom) }
        else if let anchor { proxy.scrollTo(anchor, anchor: .top) }
    }
}
