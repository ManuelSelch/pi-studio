import Foundation
import SwiftStreamingMarkdown

/// Adapts projected message snapshots to the renderer, including re-entry after a view disappears.
final class MarkdownSnapshotSource: StreamedMarkdownSource, @unchecked Sendable {
    private let lock = NSLock()
    private var current: String
    private var subscribers: [UUID: AsyncStream<String>.Continuation] = [:]

    init(initialText: String) { current = initialText }

    var text: AsyncStream<String> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let id = UUID()
            lock.lock()
            subscribers[id] = continuation
            continuation.yield(current)
            lock.unlock()
            continuation.onTermination = { [weak self] _ in self?.removeSubscriber(id) }
        }
    }

    func update(_ snapshot: String) {
        lock.lock()
        current = snapshot
        for continuation in subscribers.values { continuation.yield(snapshot) }
        lock.unlock()
    }

    private func removeSubscriber(_ id: UUID) {
        lock.lock()
        subscribers.removeValue(forKey: id)
        lock.unlock()
    }
}
