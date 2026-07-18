import Foundation

// MARK: - Cross-line state

/// State carried from one line to the next. Markdown coloring is line-local
/// except for two constructs that span lines: fenced code blocks and the YAML
/// front-matter block at the very top of the document.
enum LineState: Equatable {
    case normal
    /// Inside a ``` / ~~~ fenced code block.
    case fenced(fence: UInt16, count: Int)
    /// Inside the leading `---` front-matter block.
    case frontMatter
}

// MARK: - Tokens

enum TokenKind: Equatable {
    case headingMarker, heading
    case strong, emphasis, strikethrough
    case codeFence, codeBlock, inlineCode
    case listMarker, taskMarker
    case blockquote
    case linkText, linkURL, linkPunct
    case image
    case thematicBreak
    case autolink
    case tableDelim
    case frontMatterFence, frontMatter
    case html
}

/// A colored span, in absolute UTF-16 offsets within the whole document.
struct MDToken: Equatable {
    let range: NSRange
    let kind: TokenKind
}

// MARK: - Tokenizer

/// Pure, allocation-light tokenizer that colors ONE line given the state it
/// inherits from the previous line. Produces absolute UTF-16 ranges and the
/// state the next line should inherit. No whole-document work, ever.
struct MarkdownLineTokenizer {

    // UTF-16 code units we test against.
    private static let hash: UInt16 = 0x23      // #
    private static let star: UInt16 = 0x2A      // *
    private static let under: UInt16 = 0x5F     // _
    private static let tilde: UInt16 = 0x7E     // ~
    private static let backtick: UInt16 = 0x60  // `
    private static let gt: UInt16 = 0x3E        // >
    private static let dash: UInt16 = 0x2D      // -
    private static let plus: UInt16 = 0x2B      // +
    private static let space: UInt16 = 0x20
    private static let tab: UInt16 = 0x09
    private static let bang: UInt16 = 0x21       // !
    private static let lbracket: UInt16 = 0x5B   // [
    private static let rbracket: UInt16 = 0x5D   // ]
    private static let lparen: UInt16 = 0x28     // (
    private static let rparen: UInt16 = 0x29     // )
    private static let backslash: UInt16 = 0x5C  // \
    private static let lt: UInt16 = 0x3C         // <
    private static let pipe: UInt16 = 0x7C       // |
    private static let colon: UInt16 = 0x3A      // :

    func tokenize(line: String, lineStart: Int, lineIndex: Int,
                  entry: LineState) -> (tokens: [MDToken], exit: LineState) {
        let c = Array(line.utf16)
        let n = c.count
        var tokens: [MDToken] = []

        func add(_ start: Int, _ length: Int, _ kind: TokenKind) {
            guard length > 0, start >= 0, start + length <= n else { return }
            tokens.append(MDToken(range: NSRange(location: lineStart + start, length: length), kind: kind))
        }

        // --- Front matter -------------------------------------------------
        if entry == .frontMatter {
            if isFence(c, n, Self.dash, 3) {
                add(0, n, .frontMatterFence)
                return (tokens, .normal)
            }
            add(0, n, .frontMatter)
            return (tokens, .frontMatter)
        }
        if lineIndex == 0, isExactly(c, n, Self.dash, 3) {
            add(0, n, .frontMatterFence)
            return (tokens, .frontMatter)
        }

        // --- Fenced code block --------------------------------------------
        if case let .fenced(fence, count) = entry {
            if isFence(c, n, fence, count) {
                add(0, n, .codeFence)
                return (tokens, .normal)
            }
            add(0, n, .codeBlock)
            return (tokens, .fenced(fence: fence, count: count))
        }

        let indent = leadingSpaces(c, n)
        // Opening code fence (≤3 spaces indent, run of ≥3 ` or ~).
        if indent <= 3 {
            let ch = indent < n ? c[indent] : 0
            if ch == Self.backtick || ch == Self.tilde {
                let run = runLength(c, indent, n, ch)
                if run >= 3 {
                    add(0, n, .codeFence)
                    return (tokens, .fenced(fence: ch, count: run))
                }
            }
        }

        // --- Thematic break (---, ***, ___) -------------------------------
        if isThematicBreak(c, n, indent) {
            add(0, n, .thematicBreak)
            return (tokens, .normal)
        }

        // --- ATX heading --------------------------------------------------
        if indent <= 3, indent < n, c[indent] == Self.hash {
            let hashes = runLength(c, indent, n, Self.hash)
            let after = indent + hashes
            if hashes <= 6, (after >= n || c[after] == Self.space || c[after] == Self.tab) {
                add(indent, hashes, .headingMarker)
                add(after, n - after, .heading)
                // still scan the heading text for inline emphasis/code/links
                scanInline(c, after, n, lineStart, &tokens)
                return (tokens, .normal)
            }
        }

        // --- Blockquote marker(s) -----------------------------------------
        var scanStart = indent
        if indent < n, c[indent] == Self.gt {
            var q = indent
            while q < n, c[q] == Self.gt || c[q] == Self.space { q += 1 }
            add(indent, q - indent, .blockquote)
            scanStart = q
        }

        // --- List marker + task checkbox ----------------------------------
        if let (markerEnd, isTaskable) = listMarker(c, scanStart, n) {
            add(scanStart, markerEnd - scanStart, .listMarker)
            var afterMarker = markerEnd
            if isTaskable, let taskEnd = taskCheckbox(c, markerEnd, n) {
                add(markerEnd, taskEnd - markerEnd, .taskMarker)
                afterMarker = taskEnd
            }
            scanStart = afterMarker
        }

        // --- Table pipes (light heuristic) --------------------------------
        if lineContains(c, n, Self.pipe) {
            if isTableDelimiterRow(c, n) {
                add(0, n, .tableDelim)
                return (tokens, .normal)
            }
            markPipes(c, scanStart, n, lineStart, &tokens)
        }

        // --- Inline scan over the remainder -------------------------------
        scanInline(c, scanStart, n, lineStart, &tokens)
        return (tokens, .normal)
    }

    // MARK: - Inline scanner

    private func scanInline(_ c: [UInt16], _ start: Int, _ end: Int,
                            _ lineStart: Int, _ tokens: inout [MDToken]) {
        func add(_ s: Int, _ len: Int, _ kind: TokenKind) {
            guard len > 0, s >= 0, s + len <= c.count else { return }
            tokens.append(MDToken(range: NSRange(location: lineStart + s, length: len), kind: kind))
        }

        var i = start
        while i < end {
            let ch = c[i]
            // Backslash escape — skip the escaped char so it can't open a span.
            if ch == Self.backslash, i + 1 < end {
                i += 2
                continue
            }
            // Inline code span: `code`, ``co`de``, …
            if ch == Self.backtick {
                let run = runLength(c, i, end, Self.backtick)
                if let close = findRun(c, i + run, end, Self.backtick, run) {
                    add(i, close + run - i, .inlineCode)
                    i = close + run
                    continue
                }
                i += run
                continue
            }
            // Image ![alt](url)
            if ch == Self.bang, i + 1 < end, c[i + 1] == Self.lbracket {
                if let next = parseLink(c, i + 1, end, lineStart, isImage: true, &tokens, bangAt: i) {
                    i = next
                    continue
                }
            }
            // Link [text](url) or [text][ref] or [text]
            if ch == Self.lbracket {
                if let next = parseLink(c, i, end, lineStart, isImage: false, &tokens, bangAt: nil) {
                    i = next
                    continue
                }
            }
            // Autolink <https://…> or <a@b.com>
            if ch == Self.lt, let close = indexOf(c, i + 1, end, Self.gt), close > i + 1 {
                if looksLikeAutolink(c, i + 1, close) {
                    add(i, close + 1 - i, .autolink)
                    i = close + 1
                    continue
                }
            }
            // Strong / emphasis
            if ch == Self.star || ch == Self.under {
                let run = runLength(c, i, end, ch)
                if run >= 2, let close = findRun(c, i + 2, end, ch, 2) {
                    add(i, close + 2 - i, .strong)
                    i = close + 2
                    continue
                }
                if run >= 1, let close = findRun(c, i + 1, end, ch, 1) {
                    add(i, close + 1 - i, .emphasis)
                    i = close + 1
                    continue
                }
                i += run
                continue
            }
            // Strikethrough ~~text~~
            if ch == Self.tilde {
                let run = runLength(c, i, end, Self.tilde)
                if run >= 2, let close = findRun(c, i + 2, end, Self.tilde, 2) {
                    add(i, close + 2 - i, .strikethrough)
                    i = close + 2
                    continue
                }
                i += run
                continue
            }
            i += 1
        }
    }

    /// Parse `[text](url)` / `[text][ref]` / `[text]` (or the image variant).
    /// Returns the index just past the construct, or nil if it isn't one.
    private func parseLink(_ c: [UInt16], _ open: Int, _ end: Int, _ lineStart: Int,
                           isImage: Bool, _ tokens: inout [MDToken], bangAt: Int?) -> Int? {
        // Find matching ] with one level of [] nesting tolerance.
        var depth = 0
        var j = open
        while j < end {
            if c[j] == Self.backslash { j += 2; continue }
            if c[j] == Self.lbracket { depth += 1 }
            else if c[j] == Self.rbracket { depth -= 1; if depth == 0 { break } }
            j += 1
        }
        guard j < end, c[j] == Self.rbracket else { return nil }
        let textKind: TokenKind = isImage ? .image : .linkText
        let labelStart = bangAt ?? open
        func add(_ s: Int, _ len: Int, _ kind: TokenKind) {
            guard len > 0, s >= 0, s + len <= c.count else { return }
            tokens.append(MDToken(range: NSRange(location: lineStart + s, length: len), kind: kind))
        }
        // Inline link: [text](url)
        if j + 1 < end, c[j + 1] == Self.lparen {
            var k = j + 2
            while k < end, c[k] != Self.rparen {
                if c[k] == Self.backslash { k += 1 }
                k += 1
            }
            if k < end, c[k] == Self.rparen {
                add(labelStart, j + 1 - labelStart, textKind)   // [text] (or ![text])
                add(j + 1, 1, .linkPunct)                       // (
                add(j + 2, k - (j + 2), .linkURL)               // url
                add(k, 1, .linkPunct)                           // )
                return k + 1
            }
        }
        // Reference link [text][ref] — color the label, leave ref plain.
        add(labelStart, j + 1 - labelStart, textKind)
        return j + 1
    }

    // MARK: - Small scanners

    private func leadingSpaces(_ c: [UInt16], _ n: Int) -> Int {
        MarkdownGrammar.leadingIndent(c, n)
    }

    private func runLength(_ c: [UInt16], _ from: Int, _ end: Int, _ ch: UInt16) -> Int {
        var i = from
        while i < end, c[i] == ch { i += 1 }
        return i - from
    }

    /// Index where a run of ≥`count` `ch` begins, searching [from, end).
    private func findRun(_ c: [UInt16], _ from: Int, _ end: Int, _ ch: UInt16, _ count: Int) -> Int? {
        var i = from
        while i < end {
            if c[i] == ch {
                var k = i
                while k < end, c[k] == ch { k += 1 }
                if k - i >= count { return i }
                i = k
            } else {
                i += 1
            }
        }
        return nil
    }

    private func indexOf(_ c: [UInt16], _ from: Int, _ end: Int, _ ch: UInt16) -> Int? {
        var i = from
        while i < end { if c[i] == ch { return i }; i += 1 }
        return nil
    }

    private func lineContains(_ c: [UInt16], _ n: Int, _ ch: UInt16) -> Bool {
        for i in 0..<n where c[i] == ch { return true }
        return false
    }

    /// A run of ≥`count` `ch` starting at the first non-space, rest blank.
    private func isFence(_ c: [UInt16], _ n: Int, _ ch: UInt16, _ count: Int) -> Bool {
        MarkdownGrammar.isClosingFence(c, n, fence: ch, count: count)
    }

    private func isExactly(_ c: [UInt16], _ n: Int, _ ch: UInt16, _ count: Int) -> Bool {
        let run = runLength(c, 0, n, ch)
        guard run >= count else { return false }
        for i in run..<n where c[i] != Self.space && c[i] != Self.tab { return false }
        return true
    }

    private func isThematicBreak(_ c: [UInt16], _ n: Int, _ indent: Int) -> Bool {
        guard indent <= 3, indent < n else { return false }
        let ch = c[indent]
        guard ch == Self.dash || ch == Self.star || ch == Self.under else { return false }
        var count = 0
        for i in indent..<n {
            if c[i] == ch { count += 1 }
            else if c[i] != Self.space && c[i] != Self.tab { return false }
        }
        return count >= 3
    }

    /// Returns (indexAfterMarker, isTaskable) if a list bullet/number starts here.
    private func listMarker(_ c: [UInt16], _ start: Int, _ n: Int) -> (Int, Bool)? {
        guard let marker = MarkdownGrammar.listMarker(c, start, n) else { return nil }
        if case .bullet = marker.kind { return (marker.afterMarker, true) }
        return (marker.afterMarker, false)
    }

    /// `[ ]`, `[x]`, `[X]` right after a list marker.
    private func taskCheckbox(_ c: [UInt16], _ start: Int, _ n: Int) -> Int? {
        MarkdownGrammar.taskCheckbox(c, start, n)
    }

    private func isTableDelimiterRow(_ c: [UInt16], _ n: Int) -> Bool {
        var sawDash = false
        for i in 0..<n {
            let ch = c[i]
            if ch == Self.dash { sawDash = true }
            else if ch != Self.pipe && ch != Self.colon && ch != Self.space && ch != Self.tab {
                return false
            }
        }
        return sawDash
    }

    private func markPipes(_ c: [UInt16], _ start: Int, _ n: Int,
                           _ lineStart: Int, _ tokens: inout [MDToken]) {
        var i = start
        while i < n {
            if c[i] == Self.backslash { i += 2; continue }
            if c[i] == Self.pipe {
                tokens.append(MDToken(range: NSRange(location: lineStart + i, length: 1), kind: .tableDelim))
            }
            i += 1
        }
    }

    private func looksLikeAutolink(_ c: [UInt16], _ start: Int, _ end: Int) -> Bool {
        // Reject spaces; require a scheme colon or an @ (email).
        var hasColon = false, hasAt = false
        for i in start..<end {
            let ch = c[i]
            if ch == Self.space || ch == Self.tab { return false }
            if ch == Self.colon { hasColon = true }
            if ch == 0x40 { hasAt = true }
        }
        return hasColon || hasAt
    }
}
