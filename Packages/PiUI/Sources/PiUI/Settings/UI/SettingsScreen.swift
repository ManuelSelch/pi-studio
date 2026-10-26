import SwiftUI

struct SettingsScreen: View {
    let endpoint: String
    let error: String?
    let isSaving: Bool
    let onEndpointChanged: @MainActor (String) -> Void
    let onSave: @MainActor () -> Void
    let onCancel: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings").font(.title2.bold())
            VStack(alignment: .leading, spacing: 8) {
                Text("Pi Server endpoint").font(.subheadline.weight(.semibold))
                endpointField
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Pi Server endpoint")
                    .accessibilityIdentifier("endpointField")
                    .disabled(isSaving)
                if let error {
                    Text(verbatim: error)
                        .font(.subheadline).foregroundStyle(.red)
                        .accessibilityIdentifier("settingsError")
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("cancelSettingsButton")
                Button("Save", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("saveSettingsButton")
            }
            .disabled(isSaving)
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 440)
        #endif
    }

    private var endpointField: some View {
        TextField("", text: Binding(get: { endpoint }, set: { onEndpointChanged($0) }))
            .autocorrectionDisabled()
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            #endif
    }
}
