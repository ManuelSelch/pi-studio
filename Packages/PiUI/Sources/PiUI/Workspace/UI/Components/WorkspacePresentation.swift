import Foundation

/// Plain values for the workspace shell: no Flux, SDK types or service lookups.
public struct WorkspaceSelection: Equatable, Sendable {
    public var title: String
    /// Runtime and saved-path identity of the selected tab.
    public var runtimeId: String
    public var sessionPath: String?
    /// Project and optional branch shown as the conversation context.
    public var context: String

    public init(title: String, runtimeId: String, sessionPath: String? = nil, context: String) {
        self.title = title; self.runtimeId = runtimeId; self.sessionPath = sessionPath; self.context = context
    }

    /// A row is selected when either identity matches: the same history and the runtime
    /// attached to it must not both look selected, nor neither.
    public func represents(_ row: ProjectSessionRow) -> Bool {
        row.runtimeId == runtimeId || (sessionPath != nil && row.sessionPath == sessionPath)
    }
}

public struct WorkspacePresentation: Equatable, Sendable {
    public var status = "Disconnected"
    public var canConnect = true
    public var isBusy = false
    public var canOpen = false
    public var requiresDisconnectWarning = false
    public var error: String?
    public var groups: [ProjectGroup] = []
    public var selection: WorkspaceSelection?
    public init() {}

    /// Quick Chats stays above Activity and project groups, matching Pi Chat.
    public var quickChats: ProjectGroup? { groups.first { $0.quickChats } }
    public var projects: [ProjectGroup] { groups.filter { !$0.quickChats } }
}

/// Plain callbacks for one workspace screen. Screens never call controllers.
public struct WorkspaceActions {
    public var open: @MainActor (ProjectSessionTarget, String) -> Void
    public var create: @MainActor (String) -> Void
    public var connection: @MainActor () -> Void
    public var settings: @MainActor () -> Void
    public var back: @MainActor () -> Void
    public var draftChanged: @MainActor (String) -> Void
    public var send: @MainActor () -> Void
    public var stop: @MainActor () -> Void

    public init(open: @escaping @MainActor (ProjectSessionTarget, String) -> Void,
                create: @escaping @MainActor (String) -> Void,
                connection: @escaping @MainActor () -> Void,
                settings: @escaping @MainActor () -> Void,
                back: @escaping @MainActor () -> Void,
                draftChanged: @escaping @MainActor (String) -> Void,
                send: @escaping @MainActor () -> Void,
                stop: @escaping @MainActor () -> Void) {
        self.open = open; self.create = create; self.connection = connection
        self.settings = settings; self.back = back
        self.draftChanged = draftChanged; self.send = send; self.stop = stop
    }
}
