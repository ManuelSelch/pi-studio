import Foundation
import PiSDK

/// Catalogue-derived search values. Runtime and saved-history identities remain distinct.
enum QuickSwitcherModel {
    enum Kind: String, CaseIterable, Sendable {
        case folder, worktree, session, action
    }

    struct Item: Identifiable, Equatable, Sendable {
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
            let repository = project.repositoryName ?? catalogue.projects.first { $0.path == project.repositoryPath }?.name ?? project.name
            if project.exists {
                items.append(Item(id: "project:\(project.path)", kind: worktree ? .worktree : .folder,
                                  title: worktree ? (project.worktree?.branch ?? project.name) : project.name,
                                  detail: worktree ? repository : "", modified: 0, target: nil,
                                  projectPath: project.path, enabled: true))
            }
            for history in project.sessions where history.archivedAt == nil {
                let runtime = catalogue.sessions.first { $0.sessionPath == history.path }
                items.append(Item(id: "history:\(history.path)", kind: .session,
                                  title: runtime?.title ?? history.title,
                                  detail: [repository, project.worktree?.branch].compactMap { $0 }.joined(separator: " · "),
                                  modified: history.modified,
                                  target: runtime.map { .runtime($0.sessionId) } ?? .history(history.path),
                                  projectPath: project.path, enabled: runtime?.status != "closing"))
            }
        }
        for runtime in catalogue.sessions where !catalogue.projects.contains(where: { project in
            project.sessions.contains { $0.path == runtime.sessionPath }
        }) {
            let project = catalogue.projects.first { $0.path == runtime.projectPath }
            let repository = project?.repositoryName ?? project.flatMap { project in
                catalogue.projects.first { $0.path == project.repositoryPath }?.name
            } ?? runtime.projectName
            let detail = [repository, project?.worktree?.primary == false ? project?.worktree?.branch : nil]
                .compactMap { $0 }.joined(separator: " · ")
            items.append(Item(id: "runtime:\(runtime.sessionId)", kind: .session, title: runtime.title,
                              detail: detail, modified: 0, target: .runtime(runtime.sessionId),
                              projectPath: runtime.projectPath, enabled: runtime.status != "closing"))
        }
        let ranked = items.compactMap { item -> (Item, Double)? in
            if let scope, item.kind != scope { return nil }
            if scope == nil && text.isEmpty && item.kind != .session { return nil }
            if text.isEmpty { return (item, 0) }
            let scores = [matchScore(item.title, text), matchScore(item.detail, text).map { $0 + 10 },
                          matchScore(item.projectPath, text).map { $0 + 10 }].compactMap { $0 }
            return scores.min().map { (item, $0) }
        }
        return ranked.sorted { lhs, rhs in
            if !text.isEmpty && (lhs.0.kind == .session) != (rhs.0.kind == .session) { return lhs.0.kind != .session }
            if !text.isEmpty && lhs.0.kind != .session && lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            if lhs.0.modified != rhs.0.modified { return lhs.0.modified > rhs.0.modified }
            if lhs.0.title != rhs.0.title { return lhs.0.title.localizedStandardCompare(rhs.0.title) == .orderedAscending }
            return lhs.0.id < rhs.0.id
        }.prefix(20).map(\.0)
    }

    private static func matchScore(_ value: String, _ needle: String) -> Double? {
        let value = value.lowercased()
        if value == needle { return 0 }
        if value.hasPrefix(needle) { return 1 }
        let words = value.split(whereSeparator: { $0.isWhitespace || "/_.-".contains($0) }).map(String.init)
        if words.contains(where: { $0.hasPrefix(needle) }) { return 2 }
        if value.contains(needle) { return 3 }
        var remaining = needle[...]
        for character in value where remaining.first == character { remaining.removeFirst() }
        if remaining.isEmpty { return 4 }
        if needle.count >= 4 && words.contains(where: { singleTypo($0, needle) }) { return 5 }
        return nil
    }

    private static func singleTypo(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs), right = Array(rhs)
        guard abs(left.count - right.count) <= 1 else { return false }
        var index = 0
        while index < min(left.count, right.count) && left[index] == right[index] { index += 1 }
        if left.count == right.count {
            if index == left.count { return true }
            if left[(index + 1)...].elementsEqual(right[(index + 1)...]) { return true }
            return index + 1 < left.count && left[index] == right[index + 1] && left[index + 1] == right[index]
                && left[(index + 2)...].elementsEqual(right[(index + 2)...])
        }
        if left.count > right.count { return left[(index + 1)...].elementsEqual(right[index...]) }
        return left[index...].elementsEqual(right[(index + 1)...])
    }
}
