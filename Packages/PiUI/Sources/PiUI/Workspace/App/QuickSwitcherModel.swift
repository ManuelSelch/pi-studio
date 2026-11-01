import Foundation
import PiSDK

/// Catalogue-derived search values. Runtime and saved-history identities remain distinct.
enum QuickSwitcherModel {
    enum Kind: String, CaseIterable {
        case folder, worktree, session, action
    }

    struct Item: Identifiable {
        let id: String
        let kind: Kind
        let title: String
        let detail: String
        let modified: Double
        let target: ProjectSessionTarget?
        let projectPath: String
        let enabled: Bool
    }

    static func results(catalogue: PiCatalogue, query: String) -> [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes: [Character: Kind] = ["#": .folder, "%": .worktree, "@": .session, "/": .action]
        let scope = trimmed.first.flatMap { prefixes[$0] }
        let text = (scope == nil ? trimmed : String(trimmed.dropFirst()))
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var items: [Item] = []
        for project in catalogue.projects {
            let worktree = project.worktree?.primary == false
            items.append(Item(id: "project:\(project.path)", kind: worktree ? .worktree : .folder,
                              title: worktree ? (project.worktree?.branch ?? project.name) : project.name,
                              detail: project.displayPath, modified: 0, target: nil,
                              projectPath: project.path, enabled: project.exists))
            for history in project.sessions where history.archivedAt == nil {
                let runtime = catalogue.sessions.first { $0.sessionPath == history.path }
                items.append(Item(id: "history:\(history.path)", kind: .session,
                                  title: runtime?.title ?? history.title,
                                  detail: [project.name, project.worktree?.branch].compactMap { $0 }.joined(separator: " · "),
                                  modified: history.modified,
                                  target: runtime.map { .runtime($0.sessionId) } ?? .history(history.path),
                                  projectPath: project.path, enabled: runtime?.status != "closing"))
            }
        }
        for runtime in catalogue.sessions where !catalogue.projects.contains(where: { project in
            project.sessions.contains { $0.path == runtime.sessionPath }
        }) {
            items.append(Item(id: "runtime:\(runtime.sessionId)", kind: .session, title: runtime.title,
                              detail: runtime.projectName, modified: 0, target: .runtime(runtime.sessionId),
                              projectPath: runtime.projectPath, enabled: runtime.status != "closing"))
        }
        return items.filter { item in
            if let scope, item.kind != scope { return false }
            if scope == nil && text.isEmpty && item.kind != .session { return false }
            return text.isEmpty || item.title.lowercased().contains(text) || item.detail.lowercased().contains(text)
                || item.projectPath.lowercased().contains(text)
        }.sorted { lhs, rhs in
            if !text.isEmpty && (lhs.kind == .session) != (rhs.kind == .session) { return lhs.kind != .session }
            if lhs.modified != rhs.modified { return lhs.modified > rhs.modified }
            if lhs.title != rhs.title { return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending }
            return lhs.id < rhs.id
        }.prefix(20).map { $0 }
    }
}
