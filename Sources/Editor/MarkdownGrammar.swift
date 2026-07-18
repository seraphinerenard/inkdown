import Foundation

/// Single source of truth for Markdown line-grammar primitives, shared by the
/// editor tokenizer, the list-continuation logic, and the outline extractor —
/// so they cannot drift on tabs, fence rules, or heading limits (they used to).
/// Operates on UTF-16 code units, the space NSTextView / NSString use.
enum MarkdownGrammar {
    static let hash: UInt16 = 0x23
    static let star: UInt16 = 0x2A
    static let plus: UInt16 = 0x2B
    static let dash: UInt16 = 0x2D
    static let space: UInt16 = 0x20
    static let tab: UInt16 = 0x09
    static let backtick: UInt16 = 0x60
    static let tilde: UInt16 = 0x7E
    static let lbracket: UInt16 = 0x5B
    static let rbracket: UInt16 = 0x5D
    static let newline: UInt16 = 0x0A

    static func leadingIndent(_ c: [UInt16], _ n: Int) -> Int {
        var i = 0
        while i < n, c[i] == space || c[i] == tab { i += 1 }
        return i
    }

    static func runLength(_ c: [UInt16], _ from: Int, _ end: Int, _ ch: UInt16) -> Int {
        var i = from
        while i < end, c[i] == ch { i += 1 }
        return i - from
    }

    /// ATX heading: ≤3-space indent, 1–6 `#`, then space/EOL.
    static func atxHeading(_ c: [UInt16], _ n: Int) -> (level: Int, markerLength: Int, contentStart: Int)? {
        let indent = leadingIndent(c, n)
        guard indent <= 3, indent < n, c[indent] == hash else { return nil }
        let hashes = runLength(c, indent, n, hash)
        let after = indent + hashes
        guard hashes <= 6, after >= n || c[after] == space || c[after] == tab else { return nil }
        return (hashes, indent + hashes, after)
    }

    enum ListMarker {
        case bullet(UInt16)
        case ordered(Int, separator: UInt16)
    }

    /// A list bullet/number at `start`; returns the kind and the index just past
    /// "marker + one space".
    static func listMarker(_ c: [UInt16], _ start: Int, _ n: Int) -> (kind: ListMarker, afterMarker: Int)? {
        guard start < n else { return nil }
        let ch = c[start]
        if ch == dash || ch == star || ch == plus {
            guard start + 1 < n, c[start + 1] == space || c[start + 1] == tab else { return nil }
            return (.bullet(ch), start + 2)
        }
        var i = start
        var ordinal = 0
        while i < n, c[i] >= 0x30, c[i] <= 0x39 { ordinal = ordinal * 10 + Int(c[i] - 0x30); i += 1 }
        if i > start, i < n, c[i] == 0x2E || c[i] == 0x29, i + 1 < n, c[i + 1] == space || c[i + 1] == tab {
            return (.ordered(ordinal, separator: c[i]), i + 2)
        }
        return nil
    }

    /// `[ ]`, `[x]`, `[X]` immediately after a bullet marker; returns index past it.
    static func taskCheckbox(_ c: [UInt16], _ start: Int, _ n: Int) -> Int? {
        guard start + 2 < n, c[start] == lbracket, c[start + 2] == rbracket else { return nil }
        let mid = c[start + 1]
        guard mid == space || mid == 0x78 || mid == 0x58 else { return nil }   // ' ', x, X
        return start + 3
    }

    /// Opening code fence: ≤3-space indent, run ≥3 of ` or ~.
    static func openingFence(_ c: [UInt16], _ n: Int) -> (fence: UInt16, count: Int)? {
        let indent = leadingIndent(c, n)
        guard indent <= 3, indent < n else { return nil }
        let ch = c[indent]
        guard ch == backtick || ch == tilde else { return nil }
        let run = runLength(c, indent, n, ch)
        return run >= 3 ? (ch, run) : nil
    }

    /// A closing fence for an open `fence`×`count` block, OR any full line that is
    /// ≥`count` of `fence` with only trailing whitespace (used for `---` too).
    static func isClosingFence(_ c: [UInt16], _ n: Int, fence: UInt16, count: Int) -> Bool {
        let indent = leadingIndent(c, n)
        guard indent <= 3 else { return false }
        let run = runLength(c, indent, n, fence)
        guard run >= count else { return false }
        for i in (indent + run)..<n where c[i] != space && c[i] != tab { return false }
        return true
    }
}
