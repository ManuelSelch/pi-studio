import Testing
@testable import PiUI

struct MarkdownPromptWhitespaceTests {
    @Test func preservesPlainParagraphIndentationAndTerminalNewline() {
        #expect(MarkdownPromptWhitespace.prepare("First\n  second\n") == "First\n&#32;&#32;second&#10;")
        #expect(MarkdownPromptWhitespace.prepare("  First\n  second") == "&#32;&#32;First\n&#32;&#32;second")
    }

    @Test func leavesMarkdownStructureAndFencedCodeUnchanged() {
        let text = "  # Heading\n\n  - item\n\n```swift\n  let x = 1\n```"
        #expect(MarkdownPromptWhitespace.prepare(text) == text)
    }

    @Test func doesNotAlterIndentedListContinuations() {
        let text = "- item\n  continuation\n  - nested\n\n> quote\n>   continuation"
        #expect(MarkdownPromptWhitespace.prepare(text) == text)
    }

    @Test func preservesIndentationAlongsideInlineFormatting() {
        #expect(MarkdownPromptWhitespace.prepare("  **bold** and `code`") == "&#32;&#32;**bold** and `code`")
    }
}
