import PiSDK

public enum SessionInboxModel {
    public static func sessions(_ catalogue: PiCatalogue, laterPaths: Set<String>) -> [InboxSession] {
        ProjectListModel.groups(catalogue).flatMap(\.sessions).compactMap { row in
            if row.activity == .closing { return nil }
            let status: InboxSession.Status
            switch row.activity {
            case .needsYou: status = .needsYou
            case .running: status = .running
            case .closing: return nil
            case nil:
                status = row.sessionPath.map(laterPaths.contains) == true ? .later : .ready
            }
            return InboxSession(row: row, status: status)
        }
    }
}
