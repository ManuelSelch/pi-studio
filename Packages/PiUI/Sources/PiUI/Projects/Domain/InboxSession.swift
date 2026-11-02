import Foundation

public struct InboxSession: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable { case needsYou, ready, running, later }
    public let row: ProjectSessionRow
    public let status: Status
    public let displayLines: [String]
    public var id: String { row.id }
    public var canMoveLater: Bool { status == .ready && row.sessionPath != nil }
    public var canArchive: Bool { (status == .ready || status == .later) && row.sessionPath != nil }
}
