import Testing
import AppKit
@testable import MarkdownEditor

@Suite("MarkdownStyler Tests")
struct MarkdownStylerTests {
    let styler = MarkdownStyler(theme: .shared)

    @Test func stylesHeadingWithLargeBoldFont() {
        let text = "# Hello World"
        let ranges = styler.styledRanges(for: text)

        let headingRange = ranges.first { range in
            let font = range.attributes[.font] as? NSFont
            return font?.pointSize == Theme.shared.headingSizes[0]
        }
        #expect(headingRange != nil)
    }

    @Test func marksHeadingSyntaxCharacters() {
        let text = "# Hello"
        let ranges = styler.styledRanges(for: text)

        let syntaxRanges = ranges.filter { $0.isSyntax }
        #expect(!syntaxRanges.isEmpty)

        // The "# " prefix should be marked as syntax
        let syntaxText = syntaxRanges.map { (text as NSString).substring(with: $0.nsRange) }
        #expect(syntaxText.contains("# "))
    }

    @Test func stylesBoldText() {
        let text = "Hello **world** there"
        let ranges = styler.styledRanges(for: text)

        let boldRange = ranges.first { range in
            let font = range.attributes[.font] as? NSFont
            return font == Theme.shared.boldFont
        }
        #expect(boldRange != nil)
    }

    @Test func stylesItalicText() {
        let text = "Hello *world* there"
        let ranges = styler.styledRanges(for: text)

        let italicRange = ranges.first { range in
            let font = range.attributes[.font] as? NSFont
            return font == Theme.shared.italicFont
        }
        #expect(italicRange != nil)
    }

    @Test func stylesInlineCodeWithMonospace() {
        let text = "Use `print()` here"
        let ranges = styler.styledRanges(for: text)

        let codeRange = ranges.first { range in
            let font = range.attributes[.font] as? NSFont
            return font == Theme.shared.codeFont
        }
        #expect(codeRange != nil)
    }

    @Test func marksBoldDelimitersAsSyntax() {
        let text = "Hello **world** there"
        let ranges = styler.styledRanges(for: text)

        let syntaxRanges = ranges.filter { $0.isSyntax }
        let syntaxTexts = syntaxRanges.map { (text as NSString).substring(with: $0.nsRange) }
        #expect(syntaxTexts.contains("**"))
    }

    @Test func emptyTextProducesNoRanges() {
        let ranges = styler.styledRanges(for: "")
        #expect(ranges.isEmpty)
    }

    @Test func plainTextProducesNoRanges() {
        let ranges = styler.styledRanges(for: "Just some plain text")
        #expect(ranges.isEmpty)
    }

    @Test func h2HeadingUsesCorrectFontSize() {
        let text = "## Second Level"
        let ranges = styler.styledRanges(for: text)

        let headingRange = ranges.first { range in
            let font = range.attributes[.font] as? NSFont
            return font?.pointSize == Theme.shared.headingSizes[1]
        }
        #expect(headingRange != nil)
    }
}
