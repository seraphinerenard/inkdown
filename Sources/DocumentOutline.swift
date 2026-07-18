import Foundation

/// One heading in the document outline.
struct HeadingItem: Identifiable, Hashable {
    let id = UUID()
    let level: Int
    let title: String
    let line: Int          // 0-based source line
}

/// Extracts the heading hierarchy for the Outline panel. Uses the shared
/// `MarkdownGrammar` for fence and heading rules, so the outline can never
/// disagree with the editor's coloring about what is code vs. a heading.
enum DocumentOutline {
    static func headings(from text: String) -> [HeadingItem] {
        var result: [HeadingItem] = []
        var openFence: (fence: UInt16, count: Int)?

        for (index, line) in text.components(separatedBy: "\n").enumerated() {
            let c = Array(line.utf16)
            let n = c.count
            if let fence = openFence {
                if MarkdownGrammar.isClosingFence(c, n, fence: fence.fence, count: fence.count) {
                    openFence = nil
                }
                continue
            }
            if let fence = MarkdownGrammar.openingFence(c, n) { openFence = fence; continue }
            if let heading = MarkdownGrammar.atxHeading(c, n) {
                let start = min(heading.contentStart, n)
                let title = String(utf16CodeUnits: Array(c[start..<n]), count: n - start)
                    .trimmingCharacters(in: .whitespaces)
                result.append(HeadingItem(level: heading.level,
                                          title: title.isEmpty ? "(untitled)" : title,
                                          line: index))
            }
        }
        return result
    }
}
