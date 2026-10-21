import Foundation

/// Where a local tab points on one server. The runtime identity can change under an
/// open tab (the server replaces a runtime atomically), so the tab key is derived from
/// the saved session path when there is one and never from the runtime ID alone.
public struct OpenSessionIdentity: Equatable, Sendable {
    /// Server scope: sessions from different servers never share a tab.
    public let scope: String
    public let sessionPath: String?
    public let runtimeId: String
    public let projectPath: String

    public init(scope: String, sessionPath: String?, runtimeId: String, projectPath: String) {
        self.scope = scope; self.sessionPath = sessionPath
        self.runtimeId = runtimeId; self.projectPath = projectPath
    }

    /// Stable for the app lifetime; a replacement keeps the same key.
    public var key: String {
        sessionPath.map { "\(scope)|session:\($0)" } ?? "\(scope)|runtime:\(runtimeId)"
    }
}

/// One locally open session: the tab. It is application state, not an SDK runtime:
/// closing it never aborts or archives server work.
public struct OpenSession: Identifiable, Equatable, Sendable {
    public let id: String
    public let scope: String
    public var title: String
    public var projectPath: String
    public var sessionPath: String?
    public var runtimeId: String
    /// Authoritative run status from the server inventory, not a local guess.
    public var activity: SessionActivity?
    public var draft: String
    public var followTail: Bool
    public var unread: Bool

    public init(identity: OpenSessionIdentity, title: String, activity: SessionActivity? = nil) {
        id = identity.key; scope = identity.scope; sessionPath = identity.sessionPath
        runtimeId = identity.runtimeId; projectPath = identity.projectPath
        self.title = title; self.activity = activity
        draft = ""; followTail = true; unread = false
    }

    /// The same local session, even when one side names the saved path and the other a
    /// live runtime attached to it.
    public func matches(_ identity: OpenSessionIdentity) -> Bool {
        id == identity.key || runtimeId == identity.runtimeId
            || (sessionPath != nil && sessionPath == identity.sessionPath)
    }
}
