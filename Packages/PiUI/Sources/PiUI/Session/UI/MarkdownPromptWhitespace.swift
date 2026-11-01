import Foundation
import Markdown

/// Preserve visible indentation in top-level paragraphs without rewriting Markdown blocks.
enum MarkdownPromptWhitespace {
    static func prepare(_ text: String) -> String {
        let document = Document(parsing: text)
        var lines = text.components(separatedBy: "\n")
        var paragraphLines = Set<Int>()
        for child in document.children {
            guard child is Paragraph, let range = child.range else { continue }
            let end = range.upperBound.column == 1 ? range.upperBound.line - 1 : range.upperBound.line
            guard range.lowerBound.line <= end else { continue }
            paragraphLines.formUnion(range.lowerBound.line...end)
        }
        for lineNumber in paragraphLines.sorted() {
            let index = lineNumber - 1
            guard lines.indices.contains(index) else { continue }
            let line = lines[index]
            let spaces = line.prefix(while: { $0 == " " }).count
            guard spaces > 0, spaces <= 3, spaces < line.count else { continue }
            lines[index] = String(repeating: "&#32;", count: spaces) + line.dropFirst(spaces)
        }
        let trailing = lines.reversed().prefix(while: \.isEmpty).count
        if trailing > 0, trailing < lines.count, paragraphLines.contains(lines.count - trailing) {
            lines.removeLast(trailing)
            lines[lines.count - 1] += String(repeating: "&#10;", count: trailing)
        }
        return lines.joined(separator: "\n")
    }
}
