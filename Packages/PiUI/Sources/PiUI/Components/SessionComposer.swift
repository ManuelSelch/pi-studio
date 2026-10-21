import SwiftUI

struct SessionComposer: View {
    @State private var draft = ""
    let clearDraftMatching: String?
    let hint: String
    let canEdit: Bool
    let canSend: Bool
    let canStop: Bool
    let focus: FocusState<Bool>.Binding
    let onClearDraftConsumed: @MainActor () -> Void
    let onSend: @MainActor (String) -> Void
    let onStop: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Message").font(.caption).foregroundStyle(.secondary)
            TextField("Say hello", text: $draft, axis: .vertical)
                .lineLimit(2...5).textFieldStyle(.roundedBorder).focused(focus)
                .disabled(!canEdit).accessibilityLabel("Message").accessibilityIdentifier("messageField")
            HStack(spacing: 8) {
                Text(hint).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button("Stop", action: onStop).buttonStyle(.bordered)
                    .disabled(!canStop).accessibilityIdentifier("stopButton")
                Button("Send") { onSend(draft) }.buttonStyle(.borderedProminent)
                    .disabled(!canSend || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("sendButton")
            }
        }
        .padding()
        // Only new instructions are handled. Recreating the view must not replay an old clear.
        .onChange(of: clearDraftMatching) { _, snapshot in
            guard let snapshot else { return }
            if draft == snapshot { draft = "" }
            onClearDraftConsumed()
        }
        .onAppear {
            if clearDraftMatching != nil { onClearDraftConsumed() }
        }
    }
}
