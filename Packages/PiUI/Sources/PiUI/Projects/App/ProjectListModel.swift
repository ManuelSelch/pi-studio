import PiSDK

/// Maps SDK values to plain UI data; it never infers runtime IDs from history IDs.
public enum ProjectListModel {
    public static func groups(_ catalogue: PiCatalogue) -> [ProjectGroup] {
        var projects = catalogue.projects
        for runtime in catalogue.sessions where !projects.contains(where: { $0.path == runtime.projectPath }) {
            projects.append(.init(path: runtime.projectPath, name: runtime.projectName))
        }
        let grouped = Dictionary(grouping: projects) { project in
            project.quickChats == true ? project.path : (project.repositoryPath ?? project.path)
        }
        let groups = grouped.map { key, checkouts -> (ProjectGroup, Bool, Double) in
            let primary = checkouts.first { $0.path == key } ?? checkouts.first { $0.worktree?.primary != false } ?? checkouts[0]
            var entries: [(ProjectSessionRow, Double)] = []
            for project in checkouts {
                let runtimes = catalogue.sessions.filter { $0.projectPath == project.path }
                for history in project.sessions where history.archivedAt == nil {
                    let live = runtimes.first { $0.sessionPath == history.path }
                    entries.append((row(historyPath: history.path, title: live?.title ?? history.title, live: live, project: project), history.modified))
                }
                for runtime in runtimes where !project.sessions.contains(where: { $0.path == runtime.sessionPath }) {
                    entries.append((row(historyPath: nil, title: runtime.title, live: runtime, project: project), .greatestFiniteMagnitude))
                }
            }
            entries.sort { $0.1 == $1.1 ? $0.0.id < $1.0.id : $0.1 > $1.1 }
            let quick = checkouts.contains { $0.quickChats == true }
            return (.init(id: key, name: quick ? "Quick Chats" : (primary.repositoryName ?? primary.name),
                          quickChats: quick, newSessionPath: primary.path, canCreate: primary.exists,
                          sessions: entries.map(\.0)),
                    checkouts.contains { $0.pinned == true },
                    entries.map(\.1).max() ?? 0)
        }
        return groups.sorted {
            if $0.0.quickChats != $1.0.quickChats { return $0.0.quickChats }
            if $0.1 != $1.1 { return $0.1 }
            if !$0.1 && $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.0.name == $1.0.name ? $0.0.id < $1.0.id : $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending
        }.map(\.0)
    }
    private static func row(historyPath: String?, title: String, live: PiRuntimeSummary?, project: PiProjectSummary) -> ProjectSessionRow {
        return .init(id: historyPath ?? "runtime:\(live!.sessionId)", title: title,
                     detail: project.worktree?.branch, activity: live.flatMap { SessionActivity(runtimeStatus: $0.status) },
                     target: live.map { .runtime($0.sessionId) } ?? .history(historyPath!),
                     canOpen: live?.status != "closing",
                     runtimeId: live?.sessionId, sessionPath: historyPath ?? live?.sessionPath)
    }
}
