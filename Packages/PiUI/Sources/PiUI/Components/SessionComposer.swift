import SwiftUI

struct SessionComposer: View {
    let draft: String
    let hint: String
    let canEdit: Bool
    let canSend: Bool
    let canStop: Bool
    let focus: FocusState<Bool>.Binding
    let onDraftChanged: @MainActor (String) -> Void
    let onSend: @MainActor () -> Void
    let onStop: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Message").font(.caption).foregroundStyle(.secondary)
            TextField("Message Pi…", text: Binding(get: { draft }, set: { value in onDraftChanged(value) }), axis: .vertical)
                .lineLimit(2...5).textFieldStyle(.roundedBorder).focused(focus)
                .disabled(!canEdit).accessibilityLabel("Message").accessibilityIdentifier("messageField")
            HStack(spacing: 8) {
                Text(hint).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button("Stop", action: onStop).buttonStyle(.bordered)
                    .disabled(!canStop).accessibilityIdentifier("stopButton")
                Button("Send", action: onSend).buttonStyle(.borderedProminent)
                    .disabled(!canSend).accessibilityIdentifier("sendButton")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}
