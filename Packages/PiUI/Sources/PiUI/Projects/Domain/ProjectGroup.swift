public enum ProjectSessionTarget: Equatable, Sendable {
    case runtime(String), history(String)
}
public struct ProjectSessionRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String?
    public let activity: String?
    public let target: ProjectSessionTarget
    public let canOpen: Bool
}
public struct ProjectGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let quickChats: Bool
    public let newSessionPath: String
    public let canCreate: Bool
    public let sessions: [ProjectSessionRow]
}
