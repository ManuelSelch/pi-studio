import FactoryKit
import Flux
import Foundation
import PiSDK
import Testing
@testable import PiUI

/// The composer is locked in several states; each one has to say so, because a locked Mac
/// editor looks identical to an editable one.
@MainActor
struct WorkspaceContainerTests {
    private let container = WorkspaceContainer()

    private func state(status: DemoRunStatus?, connection: PiConnectionState = .ready(.init(sessionId: "s", projectPath: "/p")),
                       sending: Bool = false, stopping: Bool = false) -> SessionFeature.State {
        var state = SessionFeature.State()
        state.connection = connection
        state.projection = status.map { DemoSessionProjection(session: .init(sessionId: "s", projectPath: "/p"), status: $0) }
        state.isSending = sending
        state.isStopping = stopping
        return state
    }

    @Test func anIdleSessionNeedsNoHint() {
        #expect(container.composerHint(state(status: .idle)).isEmpty)
    }

    @Test func everyLockedStateExplainsItself() {
        #expect(container.composerHint(state(status: .running)).contains("Generating"))
        #expect(container.composerHint(state(status: .starting)).contains("Sending"))
        #expect(container.composerHint(state(status: .aborting)).contains("Stopping"))
        #expect(container.composerHint(state(status: .idle, sending: true)).contains("Sending"))
        #expect(container.composerHint(state(status: .idle, stopping: true)).contains("Stopping"))
        #expect(container.composerHint(state(status: nil, connection: .connecting)).contains("Waiting"))
        #expect(container.composerHint(state(status: nil, connection: .disconnected)).contains("No session"))
    }
}
