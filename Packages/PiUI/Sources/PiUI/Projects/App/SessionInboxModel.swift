import PiSDK

public enum SessionInboxModel {
    public static func sessions(_ catalogue: PiCatalogue, laterPaths: Set<String>) -> [InboxSession] {
        let groups = ProjectListModel.groups(catalogue)
        let rows = groups.flatMap { group in group.sessions.map { (group.name, $0) } }
            .filter { $0.1.activity != .closing }
        let counts = Dictionary(grouping: rows, by: { $0.1.checkoutPath }).mapValues(\.count)
        return rows.compactMap { projectName, row in
            if row.activity == .closing { return nil }
            let status: InboxSession.Status
            switch row.activity {
            case .needsYou: status = .needsYou
            case .running: status = .running
            case .closing: return nil
            case nil:
                status = row.sessionPath.map(laterPaths.contains) == true ? .later : .ready
            }
            var lines = [projectName]
            if let worktree = row.detail, !worktree.isEmpty {
                lines.append(worktree)
                if counts[row.checkoutPath, default: 0] > 1 { lines.append(row.title) }
            } else {
                lines.append(row.title)
            }
            return InboxSession(row: row, status: status, displayLines: lines)
        }
    }
}
