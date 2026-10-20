import SwiftUI

struct SessionHeader: View {
    let title: String
    let status: String
    let details: String
    let canConnect: Bool
    let onConnectionTapped: @MainActor () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.largeTitle.bold())
                Spacer()
                Text("Demo session").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Text(status).font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("connectionStatus")
                Spacer()
                Button(canConnect ? "Connect" : "Disconnect", action: onConnectionTapped)
                    .buttonStyle(.bordered).accessibilityIdentifier("connectButton")
            }
            Text(details).font(.caption).foregroundStyle(.secondary)
        }
        .padding()
    }
}
