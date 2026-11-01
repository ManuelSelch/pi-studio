import SwiftUI

struct SessionComposer: View {
    /// The selected tab owns the text; the composer only edits it.
    let draft: String
    let hint: String
    let canEdit: Bool
    let canSend: Bool
    let canStop: Bool
    let isStopping: Bool
    let focus: FocusState<Bool>.Binding
    let onDraftChanged: @MainActor (String) -> Void
    let onSend: @MainActor (String) -> Void
    let onStop: @MainActor () -> Void

    private var text: Binding<String> {
        Binding(get: { draft }, set: { value in
            guard canEdit else { return }
            onDraftChanged(value)
        })
    }
    private var sendEnabled: Bool {
        canSend && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            #if !os(macOS)
            Text("Message").font(.caption).foregroundStyle(.secondary)
            #endif
            #if os(macOS)
            MacMessageEditor(text: text, canEdit: canEdit, canSend: sendEnabled,
                             focus: focus, onSend: submit)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
                }
            #else
            TextField("Say hello", text: text, axis: .vertical)
                .lineLimit(2...5).textFieldStyle(.roundedBorder).focused(focus)
                .submitLabel(.return)
                .disabled(!canEdit).accessibilityLabel("Message").accessibilityIdentifier("messageField")
            #endif
            HStack {
                Text(hint).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityIdentifier("composerHint")
                Spacer(minLength: 4)
                #if os(iOS)
                if canStop || isStopping {
                    Button(action: onStop) { Image(systemName: "stop.fill").frame(minWidth: 24, minHeight: 24) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canStop)
                        .accessibilityLabel("Stop").accessibilityIdentifier("stopButton")
                } else {
                    sendButton
                }
                #else
                sendButton
                #endif
            }
        }
        .padding()
    }

    private var sendButton: some View {
        Button(action: submit) { Image(systemName: "arrow.up").frame(minWidth: 24, minHeight: 24) }
            .buttonStyle(.borderedProminent)
            .disabled(!sendEnabled)
            .accessibilityLabel("Send").accessibilityIdentifier("sendButton")
    }

    private func submit() {
        guard sendEnabled else { return }
        #if os(macOS)
        focus.wrappedValue = true
        #endif
        onSend(draft)
    }
}
