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

/// One open session. Mac renders it as a tab, the phone as an overview row, so it carries
/// the project context as well. Unread is independent of activity.
public struct OpenSessionPresentation: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var activity: SessionActivity?
    public var isSelected: Bool
    public var unread: Bool
    /// Project path of the session, shown wherever a title alone is ambiguous.
    public var context: String

    public init(id: String, title: String, activity: SessionActivity? = nil,
                isSelected: Bool = false, unread: Bool = false, context: String = "") {
        self.id = id; self.title = title; self.activity = activity
        self.isSelected = isSelected; self.unread = unread; self.context = context
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
    /// Ordered open sessions. Mac renders them as a tab strip, the phone as its overview;
    /// the phone never shows a tab strip.
    public var openSessions: [OpenSessionPresentation] = []
    /// Project the overview's new-session action targets: Quick Chats first, like the sidebar.
    public var newSessionPath: String?
    public var isConnected = false
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
    public var send: @MainActor (String) -> Void
    public var stop: @MainActor () -> Void
    public var selectTab: @MainActor (String) -> Void
    public var closeTab: @MainActor (String) -> Void
    public var followTailChanged: @MainActor (Bool) -> Void
    public var scrollAnchorChanged: @MainActor (String?) -> Void

    public init(open: @escaping @MainActor (ProjectSessionTarget, String) -> Void,
                create: @escaping @MainActor (String) -> Void,
                connection: @escaping @MainActor () -> Void,
                settings: @escaping @MainActor () -> Void,
                back: @escaping @MainActor () -> Void,
                draftChanged: @escaping @MainActor (String) -> Void,
                send: @escaping @MainActor (String) -> Void,
                stop: @escaping @MainActor () -> Void,
                selectTab: @escaping @MainActor (String) -> Void,
                closeTab: @escaping @MainActor (String) -> Void,
                followTailChanged: @escaping @MainActor (Bool) -> Void,
                scrollAnchorChanged: @escaping @MainActor (String?) -> Void) {
        self.open = open; self.create = create; self.connection = connection
        self.settings = settings; self.back = back
        self.draftChanged = draftChanged; self.send = send; self.stop = stop
        self.selectTab = selectTab; self.closeTab = closeTab
        self.followTailChanged = followTailChanged; self.scrollAnchorChanged = scrollAnchorChanged
    }
}
