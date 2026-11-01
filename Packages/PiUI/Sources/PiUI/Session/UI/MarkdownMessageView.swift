import SwiftUI
import SwiftStreamingMarkdown

struct MarkdownMessageView: View {
    let text: String
    let preservePromptWhitespace: Bool
    @State private var source: MarkdownSnapshotSource

    init(text: String, preservePromptWhitespace: Bool) {
        self.text = text
        self.preservePromptWhitespace = preservePromptWhitespace
        _source = State(initialValue: MarkdownSnapshotSource(initialText: preservePromptWhitespace ? MarkdownPromptWhitespace.prepare(text) : text))
    }

    var body: some View {
        StreamedMarkdownView(source: source)
            .onChange(of: text) { _, snapshot in
                source.update(preservePromptWhitespace ? MarkdownPromptWhitespace.prepare(snapshot) : snapshot)
            }
    }
}
