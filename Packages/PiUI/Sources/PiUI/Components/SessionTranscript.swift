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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }
}
