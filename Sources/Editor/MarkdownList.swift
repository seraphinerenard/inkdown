import Foundation

/// Parses a source line for a list marker so the editor can continue lists on
/// Enter. Uses the shared `MarkdownGrammar`, so it stays consistent with the
/// editor's coloring and the outline.
enum MarkdownList {
    struct Info { let markerLength: Int; let continuation: String; let contentEmpty: Bool }

    static func info(for line: String) -> Info? {
        let c = Array(line.utf16)
        let n = c.count
        let indentLen = MarkdownGrammar.leadingIndent(c, n)
        guard let marker = MarkdownGrammar.listMarker(c, indentLen, n) else { return nil }
        let indent = String(utf16CodeUnits: Array(c[0..<indentLen]), count: indentLen)

        func contentEmpty(from index: Int) -> Bool {
            let start = min(index, n)
            return String(utf16CodeUnits: Array(c[start..<n]), count: n - start)
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        switch marker.kind {
        case .bullet(let bullet):
            let bulletStr = String(UnicodeScalar(bullet)!)
            var contentStart = marker.afterMarker
            var continuation = indent + bulletStr + " "
            if let taskEnd = MarkdownGrammar.taskCheckbox(c, marker.afterMarker, n) {
                contentStart = taskEnd
                if contentStart < n, c[contentStart] == MarkdownGrammar.space { contentStart += 1 }
                continuation = indent + bulletStr + " [ ] "
            }
            return Info(markerLength: contentStart, continuation: continuation,
                        contentEmpty: contentEmpty(from: contentStart))
        case .ordered(let ordinal, let separator):
            let sep = Character(UnicodeScalar(separator)!)
            return Info(markerLength: marker.afterMarker,
                        continuation: indent + "\(ordinal + 1)\(sep) ",
                        contentEmpty: contentEmpty(from: marker.afterMarker))
        }
    }
}
