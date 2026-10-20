import Foundation

enum ServerEndpoint {
    static let defaultValue = "ws://127.0.0.1:8787/ws"
    static let validationMessage = "Enter a valid ws:// or wss:// URL with a host, without credentials or a fragment."

    static func validated(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains(where: { $0.isWhitespace }),
              let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(), ["ws", "wss"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil, components.fragment == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true,
              URL(string: value) != nil else { return nil }
        return value
    }
}
