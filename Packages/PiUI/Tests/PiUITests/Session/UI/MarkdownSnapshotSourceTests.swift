import Testing
@testable import PiUI

@MainActor
struct MarkdownSnapshotSourceTests {
    @Test func deliversCompleteSnapshotsInOrder() async {
        let source = MarkdownSnapshotSource(initialText: "Hello")
        var iterator = source.text.makeAsyncIterator()

        #expect(await iterator.next() == "Hello")
        source.update("Hello **world")
        #expect(await iterator.next() == "Hello **world")
        source.update("Hello **world**")
        #expect(await iterator.next() == "Hello **world**")
    }

    @Test func newSubscribersReceiveTheLatestSnapshot() async {
        let source = MarkdownSnapshotSource(initialText: "First")
        var first = source.text.makeAsyncIterator()
        #expect(await first.next() == "First")
        source.update("Second")

        var reopened = source.text.makeAsyncIterator()
        #expect(await reopened.next() == "Second")
        source.update("Third")
        #expect(await first.next() == "Third")
        #expect(await reopened.next() == "Third")
    }

    @Test func retainsTheLatestSnapshotBeforeRenderingStarts() async {
        let source = MarkdownSnapshotSource(initialText: "Old")
        source.update("Newest")
        var iterator = source.text.makeAsyncIterator()

        #expect(await iterator.next() == "Newest")
    }
}
