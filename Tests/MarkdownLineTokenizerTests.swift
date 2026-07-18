import Testing
import AppKit
@testable import MarkdownEditor

@Suite("MarkdownLineTokenizer Tests")
struct MarkdownLineTokenizerTests {
    let tk = MarkdownLineTokenizer()

    /// Tokenize a single line (default lineIndex 1 so `---` isn't read as front matter).
    private func kinds(_ line: String, entry: LineState = .normal, index: Int = 1) -> [TokenKind] {
        tk.tokenize(line: line, lineStart: 0, lineIndex: index, entry: entry).tokens.map(\.kind)
    }

    @Test func heading() {
        let k = kinds("# Title")
        #expect(k.contains(.headingMarker))
        #expect(k.contains(.heading))
    }

    @Test func boldItalicStrikeCode() {
        #expect(kinds("a **b** c").contains(.strong))
        #expect(kinds("a *b* c").contains(.emphasis))
        #expect(kinds("a ~~b~~ c").contains(.strikethrough))
        #expect(kinds("a `b` c").contains(.inlineCode))
    }

    @Test func lists() {
        #expect(kinds("- item").contains(.listMarker))
        #expect(kinds("1. item").contains(.listMarker))
        let task = kinds("- [ ] todo")
        #expect(task.contains(.listMarker))
        #expect(task.contains(.taskMarker))
    }

    @Test func blockquote() {
        #expect(kinds("> quote").contains(.blockquote))
    }

    @Test func link() {
        let k = kinds("see [text](http://example.com)")
        #expect(k.contains(.linkText))
        #expect(k.contains(.linkURL))
    }

    @Test func thematicBreakVsFrontMatter() {
        #expect(kinds("---", index: 1).contains(.thematicBreak))
        let fm = tk.tokenize(line: "---", lineStart: 0, lineIndex: 0, entry: .normal)
        #expect(fm.exit == .frontMatter)
        #expect(fm.tokens.map(\.kind).contains(.frontMatterFence))
    }

    @Test func fencedCodeBlockStateMachine() {
        let open = tk.tokenize(line: "```swift", lineStart: 0, lineIndex: 1, entry: .normal)
        #expect(open.tokens.map(\.kind).contains(.codeFence))
        guard case .fenced = open.exit else {
            Issue.record("should enter fenced state")
            return
        }

        let inside = tk.tokenize(line: "let x = **not bold**", lineStart: 0, lineIndex: 2, entry: open.exit)
        #expect(inside.tokens.map(\.kind) == [.codeBlock])   // no inline parsing inside a fence

        let close = tk.tokenize(line: "```", lineStart: 0, lineIndex: 3, entry: inside.exit)
        #expect(close.tokens.map(\.kind).contains(.codeFence))
        #expect(close.exit == .normal)
    }

    @Test func plainProseHasNoTokens() {
        #expect(kinds("just some plain words here").isEmpty)
    }

    @Test func rangesStayInBounds() {
        let line = "# **bold** `code` [l](u)"
        let toks = tk.tokenize(line: line, lineStart: 100, lineIndex: 1, entry: .normal).tokens
        let len = (line as NSString).length
        for t in toks {
            #expect(t.range.location >= 100)
            #expect(t.range.location + t.range.length <= 100 + len)
        }
    }
}
