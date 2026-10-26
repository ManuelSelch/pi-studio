import Foundation
import PiSDK

/// The one connection the workspace owns, published so the conversation can send, stop and
/// observe its transcript without owning a transport itself.
///
/// Flux 2 has no cross-store dispatch (`Middleware`/`StoreHandle` are generic over one feature),
/// so this single injected dependency is the whole seam between `Workspace` and `Session`.
/// `WorkspaceMiddleware` is the only writer; `SessionMiddleware` only reads it.
@MainActor public final class SessionTransport {
    public internal(set) var connection: (any PiDemoConnection)?

    public init() {}

    /// Published by the workspace when it connects, and cleared when it disconnects. Attaching
    /// to a different session does not replace the connection: the SDK observes one runtime.
    public func publish(_ value: (any PiDemoConnection)?) { connection = value }
}
