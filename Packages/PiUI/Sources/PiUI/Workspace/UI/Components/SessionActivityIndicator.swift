import SwiftUI

/// One status vocabulary for every surface: green idle, yellow running, red needs
/// you. Colour never carries the meaning alone; each indicator states its label.
extension SessionActivity {
    var label: String {
        switch self {
        case .running: "Running"
        case .needsYou: "Needs you"
        case .closing: "Closing"
        }
    }

    var tint: Color {
        switch self {
        case .running: .yellow
        case .needsYou: .red
        case .closing: .secondary
        }
    }
}

struct SessionActivityIndicator: View {
    let activity: SessionActivity?

    var body: some View {
        Circle()
            .fill(activity?.tint ?? .green)
            .frame(width: 8, height: 8)
            .accessibilityElement()
            .accessibilityLabel(activity?.label ?? "Idle")
    }
}
