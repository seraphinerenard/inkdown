import AppKit

/// Drives VSCode-style source coloring for the editor. It listens to text-storage
/// edits and paints color via `NSLayoutManager` *temporary attributes* — which are
/// display-only, so the text storage is never mutated (no undo pollution, no
/// re-entrancy, no layout thrash). Line boundaries and per-line entry states are
/// maintained in UTF-16 space, so there is no O(fileSize) allocation per keystroke.
final class SyntaxHighlighter: NSObject, NSTextStorageDelegate {

    private let theme: Theme
    private let tokenizer = MarkdownLineTokenizer()

    weak var layoutManager: NSLayoutManager?
    weak var textContainer: NSTextContainer?
    weak var textView: NSTextView?

    /// UTF-16 start offset of every line; `exitStates[i]` is the state after line i.
    private var lineStarts: [Int] = [0]
    private var exitStates: [LineState] = [.normal]
    private var isHighlighting = false

    init(theme: Theme) {
        self.theme = theme
    }

    // MARK: - NSTextStorageDelegate

    func textStorage(_ textStorage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange,
                     changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters), !isHighlighting else { return }
        applyEdit(textStorage, editedRange: editedRange, delta: delta)
    }

    // MARK: - Public entry points

    /// Full re-thread of line state + repaint of the visible region. Cheap: line
    /// indexing is O(lineCount) memory, tokenizing is allocation-light, and only
    /// on-screen lines actually touch the layout manager.
    func rehighlight(_ storage: NSTextStorage) {
        guard let lm = layoutManager else { return }
        isHighlighting = true
        defer { isHighlighting = false }

        let ns = storage.string as NSString
        rebuildLineStarts(storage.string)

        let visible = visibleCharRange()
        var state = LineState.normal
        var newExit: [LineState] = []
        newExit.reserveCapacity(lineStarts.count)

        for i in 0..<lineStarts.count {
            let lr = lineRange(i, textLength: ns.length)
            let (tokens, exit) = tokenizer.tokenize(
                line: ns.substring(with: lr),
                lineStart: lr.location,
                lineIndex: i,
                entry: state)
            if shouldPaint(lr, visible: visible) {
                paint(tokens, lineRange: lr, lm: lm, textLength: ns.length)
            }
            newExit.append(exit)
            state = exit
        }
        exitStates = newExit
    }

    /// Incremental update driven by the edit itself: re-index only the edited lines
    /// and re-tokenize downward until the per-line exit state reconverges — usually
    /// a single line for ordinary typing, so there's no O(fileSize) work per key.
    /// Falls back to a full pass for the first edit, an empty prior document, or any
    /// inconsistency (correctness first; the fast path is a pure optimization).
    private func applyEdit(_ storage: NSTextStorage, editedRange: NSRange, delta: Int) {
        guard let lm = layoutManager else { return }
        let ns = storage.string as NSString
        let oldLength = ns.length - delta
        guard oldLength > 0, exitStates.count == lineStarts.count, !lineStarts.isEmpty else {
            rehighlight(storage); return
        }

        let dirty = ns.lineRange(for: editedRange)
        let newDirtyEnd = dirty.location + dirty.length
        let oldDirtyEnd = newDirtyEnd - delta

        let firstLine = lowerBound(lineStarts, dirty.location)
        guard firstLine < lineStarts.count, lineStarts[firstLine] == dirty.location else {
            rehighlight(storage); return
        }
        let lastLinePlus1 = lowerBound(lineStarts, oldDirtyEnd)
        guard lastLinePlus1 >= firstLine, lastLinePlus1 <= lineStarts.count else {
            rehighlight(storage); return
        }

        // Line starts inside the edited block (scan only that substring for newlines).
        var block: [Int] = [dirty.location]
        if dirty.length > 0 {
            let sub = ns.substring(with: dirty) as NSString
            for k in 0..<sub.length where sub.character(at: k) == 0x0A {
                let pos = dirty.location + k + 1
                if pos < newDirtyEnd { block.append(pos) }
            }
        }

        // Splice the line index + exit-state caches; shift the unchanged tail by delta.
        var starts = Array(lineStarts[0..<firstLine])
        starts.append(contentsOf: block)
        if lastLinePlus1 < lineStarts.count {
            starts.append(contentsOf: lineStarts[lastLinePlus1...].map { $0 + delta })
        }
        var exits = Array(exitStates[0..<firstLine])
        exits.append(contentsOf: Array(repeating: LineState.normal, count: block.count))
        if lastLinePlus1 < exitStates.count {
            exits.append(contentsOf: exitStates[lastLinePlus1...])
        }
        lineStarts = starts
        exitStates = exits

        // Re-tokenize from the first edited line, cascading only while the exit state
        // keeps changing past the edited block (a fence toggle ripples; typing doesn't).
        isHighlighting = true
        defer { isHighlighting = false }
        let visible = visibleCharRange()
        let lastBlockLine = firstLine + block.count - 1
        var state = firstLine == 0 ? LineState.normal : exitStates[firstLine - 1]
        var i = firstLine
        while i < lineStarts.count {
            let lr = lineRange(i, textLength: ns.length)
            let (tokens, exit) = tokenizer.tokenize(
                line: ns.substring(with: lr), lineStart: lr.location, lineIndex: i, entry: state)
            if shouldPaint(lr, visible: visible) {
                paint(tokens, lineRange: lr, lm: lm, textLength: ns.length)
            }
            let previousExit = exitStates[i]
            exitStates[i] = exit
            state = exit
            if i > lastBlockLine && exit == previousExit { break }
            i += 1
        }
    }

    private func lowerBound(_ array: [Int], _ value: Int) -> Int {
        var lo = 0, hi = array.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if array[mid] < value { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Repaint only the currently-visible lines using cached line state. Called on
    /// scroll so off-screen lines get colored the moment they appear — O(viewport).
    func restyleViewport() {
        guard let lm = layoutManager, let storage = textView?.textStorage else { return }
        guard let visible = visibleCharRange() else { return }
        isHighlighting = true
        defer { isHighlighting = false }

        let ns = storage.string as NSString
        let firstLine = lineIndex(for: visible.location)
        let lastLine = lineIndex(for: min(visible.location + visible.length, max(0, ns.length - 1)))
        guard firstLine <= lastLine else { return }

        for i in firstLine...lastLine where i < lineStarts.count {
            let lr = lineRange(i, textLength: ns.length)
            let entry = i == 0 ? .normal : exitStates[i - 1]
            let (tokens, _) = tokenizer.tokenize(
                line: ns.substring(with: lr), lineStart: lr.location, lineIndex: i, entry: entry)
            paint(tokens, lineRange: lr, lm: lm, textLength: ns.length)
        }
    }

    // MARK: - Line/offset mapping (for scroll sync)

    var lineCount: Int { lineStarts.count }

    func offset(forLine line: Int) -> Int {
        guard !lineStarts.isEmpty else { return 0 }
        return lineStarts[min(max(0, line), lineStarts.count - 1)]
    }

    func line(forOffset offset: Int) -> Int {
        lineIndex(for: max(0, offset))
    }

    /// The source line at the top of the current viewport (for editor→preview sync).
    func topVisibleLine() -> Int? {
        guard let visible = visibleCharRange() else { return nil }
        return lineIndex(for: visible.location)
    }

    // MARK: - Painting

    private func paint(_ tokens: [MDToken], lineRange: NSRange,
                       lm: NSLayoutManager, textLength: Int) {
        let clamped = NSIntersectionRange(lineRange, NSRange(location: 0, length: textLength))
        guard clamped.length > 0 else { return }
        lm.removeTemporaryAttribute(.foregroundColor, forCharacterRange: clamped)
        for token in tokens {
            let r = NSIntersectionRange(token.range, clamped)
            guard r.length > 0 else { continue }
            lm.setTemporaryAttributes([.foregroundColor: theme.color(for: token.kind)],
                                      forCharacterRange: r)
        }
    }

    // MARK: - Line index

    private func rebuildLineStarts(_ text: String) {
        var starts: [Int] = [0]
        var idx = 0
        // Lazy UTF-16 scan — no full buffer copy, so no O(byteCount) allocation.
        for unit in text.utf16 {
            idx += 1
            if unit == 0x0A { starts.append(idx) }
        }
        lineStarts = starts
    }

    private func lineRange(_ i: Int, textLength: Int) -> NSRange {
        let start = lineStarts[i]
        let end = (i + 1 < lineStarts.count) ? lineStarts[i + 1] : textLength
        return NSRange(location: start, length: max(0, end - start))
    }

    /// Binary search: index of the line containing `offset`.
    private func lineIndex(for offset: Int) -> Int {
        var lo = 0, hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= offset { lo = mid } else { hi = mid - 1 }
        }
        return lo
    }

    // MARK: - Viewport helpers

    private func visibleCharRange() -> NSRange? {
        guard let tv = textView, let lm = layoutManager, let tc = textContainer else { return nil }
        let glyphRange = lm.glyphRange(forBoundingRect: tv.visibleRect, in: tc)
        return lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
    }

    private func shouldPaint(_ lineRange: NSRange, visible: NSRange?) -> Bool {
        guard let visible else { return true }   // no viewport info → paint all
        return NSIntersectionRange(lineRange, visible).length > 0
            || lineRange.location <= visible.location + visible.length
            && lineRange.location + lineRange.length >= visible.location
    }
}
