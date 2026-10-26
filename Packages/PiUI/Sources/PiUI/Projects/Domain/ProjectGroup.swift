public enum ProjectSessionTarget: Equatable, Sendable {
    case runtime(String), history(String)
}

/// Server-owned runtime status expressed as presentation semantics. Surfaces map
/// this to colour and text; they never compare raw protocol strings themselves.
public enum SessionActivity: Equatable, Sendable {
    case running, needsYou, closing

    /// Server inventory vocabulary (`session.list.changed`): never guess from timers.
    /// `idle` is the absence of activity, so it stays `nil`.
    public init?(runtimeStatus: String) {
        switch runtimeStatus {
        case "running": self = .running
        case "blocked": self = .needsYou
        case "closing": self = .closing
        default: return nil
        }
    }
}

public struct ProjectSessionRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String?
    public let activity: SessionActivity?
    public let target: ProjectSessionTarget
    public let canOpen: Bool
    /// Identities a selected workspace session can match, so a row highlights even when
    /// the tab was opened through the other identity (saved path versus live runtime).
    public let runtimeId: String?
    public let sessionPath: String?
}
public struct ProjectGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let quickChats: Bool
    public let newSessionPath: String
    public let canCreate: Bool
    public let sessions: [ProjectSessionRow]
}
