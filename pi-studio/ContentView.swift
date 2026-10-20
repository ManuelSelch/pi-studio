import SwiftUI
import PiSDK

struct ContentView: View {
    @Environment(DemoSessionModel.self) private var model
    @State private var confirmConnect = false
    @State private var confirmDisconnect = false
    @FocusState private var messageFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if let error = model.errorMessage {
                Text(verbatim: error)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                    .accessibilityIdentifier("errorMessage")
            }
            Divider()
            transcript
            Divider()
            composer
        }
        .frame(maxWidth: 620, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .alert("Connect and take control?", isPresented: $confirmConnect) {
            Button("Cancel", role: .cancel) {}
            Button("Connect and take control") { Task { await model.connect(takingControl: true) } }
        } message: {
            Text("This replaces any current server controller and creates a fresh demo session. Existing server sessions are not closed.")
        }
        .alert("Disconnect?", isPresented: $confirmDisconnect) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) { Task { await model.disconnect() } }
        } message: {
            Text("Server work may continue. Disconnecting does not stop or close the session.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Pi Studio").font(.largeTitle.bold())
                Spacer()
                Text("Demo session").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(model.statusText).font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("connectionStatus")
                Spacer()
                Button(model.canConnect ? "Connect" : "Disconnect") {
                    messageFocused = false
                    if model.canConnect { confirmConnect = true }
                    else if model.requiresDisconnectWarning { confirmDisconnect = true }
                    else { Task { await model.disconnect() } }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("connectButton")
            }
            Text("\(model.configuration.endpoint.absoluteString) · \(model.configuration.projectPath)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if model.projection?.messages.isEmpty != false {
                        Text(model.state == .connecting ? "Preparing the demo session…" : model.canEditMessage ? "Demo ready. Send a message to begin." : "Your demo conversation will appear here.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .multilineTextAlignment(.center)
                    }
                    ForEach(model.projection?.messages ?? []) { message in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(message.role == "user" ? "You" : message.role.capitalized)
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(verbatim: message.text)
                                .textSelection(.enabled)
                                .accessibilityIdentifier("message-\(message.id)")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.projection?.messages) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private var composer: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 10) {
            Text("Message").font(.caption).foregroundStyle(.secondary)
            TextField("Say hello", text: $model.draft, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .focused($messageFocused)
                .disabled(!model.canEditMessage)
                .accessibilityLabel("Message")
                .accessibilityIdentifier("messageField")
            HStack(spacing: 8) {
                Text(model.hint).font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button("Stop") { Task { await model.stop() } }
                    .buttonStyle(.bordered)
                    .disabled(!model.canStop)
                    .accessibilityIdentifier("stopButton")
                Button("Send") {
                    messageFocused = false
                    Task { await model.send() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canSend)
                .accessibilityIdentifier("sendButton")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView().environment(DemoSessionModel())
}
