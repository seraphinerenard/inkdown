import AppKit
import Markdown

// MARK: - Custom Attribute Key

extension NSAttributedString.Key {
    /// Marks ranges that contain Markdown syntax characters (e.g. #, **, `)
    static let markdownSyntax = NSAttributedString.Key("markdownSyntax")
}

// MARK: - Styled Range

struct StyledRange {
    let nsRange: NSRange
    let attributes: [NSAttributedString.Key: Any]
    let isSyntax: Bool

    init(_ nsRange: NSRange, _ attributes: [NSAttributedString.Key: Any], isSyntax: Bool = false) {
        self.nsRange = nsRange
        self.attributes = attributes
        self.isSyntax = isSyntax
    }
}

// MARK: - Styler

class MarkdownStyler {
    let theme: Theme

    init(theme: Theme) {
        self.theme = theme
    }

    func styledRanges(for text: String) -> [StyledRange] {
        guard !text.isEmpty else { return [] }
        let document = Document(parsing: text)
        var visitor = StyleVisitor(text: text, theme: theme)
        visitor.visit(document)
        return visitor.ranges
    }
}

// MARK: - AST Visitor (struct for MarkupWalker conformance)

private struct StyleVisitor: MarkupWalker {
    let text: String
    let nsText: NSString
    let theme: Theme
    var ranges: [StyledRange] = []

    // Precomputed lookup: utf8ByteOffset -> utf16Offset (for NSRange)
    // Also stores line start offsets in UTF-8 byte space.
    private let utf8ToUTF16: [Int]   // indexed by UTF-8 byte offset, value is UTF-16 offset
    private let lineStartsUTF8: [Int] // UTF-8 byte offset for each line start

    init(text: String, theme: Theme) {
        self.text = text
        self.nsText = text as NSString
        self.theme = theme

        // Build UTF-8 byte -> UTF-16 offset mapping in a single pass.
        let utf8Count = text.utf8.count
        var mapping = [Int](repeating: 0, count: utf8Count + 1)
        var lineStarts: [Int] = [0]
        var utf8Offset = 0
        var utf16Offset = 0

        for scalar in text.unicodeScalars {
            let u8Len = scalar.utf8.count
            let u16Len = scalar.utf16.count

            // Map each UTF-8 byte in this scalar to the current UTF-16 offset
            for b in 0..<u8Len {
                mapping[utf8Offset + b] = utf16Offset
            }

            utf8Offset += u8Len
            utf16Offset += u16Len

            if scalar == "\n" {
                lineStarts.append(utf8Offset)
            }
        }
        // Sentinel: past the end
        mapping[utf8Offset] = utf16Offset

        self.utf8ToUTF16 = mapping
        self.lineStartsUTF8 = lineStarts
    }

    /// Convert swift-markdown SourceLocation to UTF-16 offset (for NSRange).
    /// SourceLocation uses 1-based line/column where column is a UTF-8 byte offset.
    private func offset(for location: SourceLocation) -> Int? {
        let line = location.line - 1
        let utf8Col = location.column - 1
        guard line >= 0, line < lineStartsUTF8.count else { return nil }

        let utf8Offset = lineStartsUTF8[line] + utf8Col
        guard utf8Offset >= 0, utf8Offset < utf8ToUTF16.count else { return nil }
        return utf8ToUTF16[utf8Offset]
    }

    /// Convert swift-markdown SourceRange to NSRange
    private func nsRange(for node: any Markup) -> NSRange? {
        guard let range = node.range else { return nil }
        guard let start = offset(for: range.lowerBound),
              let end = offset(for: range.upperBound) else { return nil }
        let length = end - start
        guard length > 0, start + length <= nsText.length else { return nil }
        return NSRange(location: start, length: length)
    }

    private func syntaxPrefixRange(for node: any Markup, prefixLength: Int) -> NSRange? {
        guard let fullRange = nsRange(for: node) else { return nil }
        let len = min(prefixLength, fullRange.length)
        guard len > 0 else { return nil }
        return NSRange(location: fullRange.location, length: len)
    }

    private func syntaxSuffixRange(for node: any Markup, suffixLength: Int) -> NSRange? {
        guard let fullRange = nsRange(for: node) else { return nil }
        let len = min(suffixLength, fullRange.length)
        guard len > 0 else { return nil }
        return NSRange(location: fullRange.location + fullRange.length - len, length: len)
    }

    private mutating func addSyntaxRange(_ range: NSRange) {
        ranges.append(StyledRange(range, [
            .foregroundColor: theme.syntaxColor,
            .markdownSyntax: true,
        ], isSyntax: true))
    }

    // MARK: - Block Elements

    mutating func visitHeading(_ heading: Heading) {
        guard let range = nsRange(for: heading) else {
            return descendInto(heading)
        }

        ranges.append(StyledRange(range, theme.headingAttributes(level: heading.level)))

        // Mark "# " prefix as syntax
        let prefixLen = heading.level + 1
        if let syntaxRange = syntaxPrefixRange(for: heading, prefixLength: prefixLen) {
            addSyntaxRange(syntaxRange)
        }

        descendInto(heading)
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        guard let range = nsRange(for: codeBlock) else { return }

        let style = NSMutableParagraphStyle()
        style.lineSpacing = theme.lineSpacing
        style.headIndent = 12
        style.firstLineHeadIndent = 12
        style.tailIndent = -12

        ranges.append(StyledRange(range, [
            .font: theme.codeFont,
            .backgroundColor: theme.codeBackground,
            .paragraphStyle: style,
        ]))

        // Mark fence lines as syntax
        let sourceText = nsText.substring(with: range)
        if sourceText.hasPrefix("```") {
            if let firstNewline = sourceText.firstIndex(of: "\n") {
                let fenceLen = sourceText.distance(from: sourceText.startIndex, to: firstNewline)
                if let syntaxRange = syntaxPrefixRange(for: codeBlock, prefixLength: fenceLen) {
                    addSyntaxRange(syntaxRange)
                }
            }
            if sourceText.hasSuffix("```\n") || sourceText.hasSuffix("```") {
                let closingLen = sourceText.hasSuffix("```\n") ? 4 : 3
                if let syntaxRange = syntaxSuffixRange(for: codeBlock, suffixLength: closingLen) {
                    addSyntaxRange(syntaxRange)
                }
            }
        }
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        guard let range = nsRange(for: blockQuote) else {
            return descendInto(blockQuote)
        }

        let style = NSMutableParagraphStyle()
        style.headIndent = 24
        style.firstLineHeadIndent = 24
        style.lineSpacing = theme.lineSpacing

        ranges.append(StyledRange(range, [
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ]))

        // Mark > prefix as syntax on each line
        let sourceText = nsText.substring(with: range)
        var lineStart = 0
        for line in sourceText.components(separatedBy: "\n") {
            if line.hasPrefix(">") {
                let prefixLen = line.hasPrefix("> ") ? 2 : 1
                let syntaxRange = NSRange(
                    location: range.location + lineStart,
                    length: min(prefixLen, nsText.length - (range.location + lineStart))
                )
                if syntaxRange.location + syntaxRange.length <= nsText.length {
                    addSyntaxRange(syntaxRange)
                }
            }
            lineStart += (line as NSString).length + 1
        }

        descendInto(blockQuote)
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        guard let range = nsRange(for: thematicBreak) else { return }
        ranges.append(StyledRange(range, [
            .foregroundColor: theme.syntaxColor,
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .strikethroughColor: NSColor.separatorColor,
        ]))
    }

    mutating func visitListItem(_ listItem: ListItem) {
        guard let range = nsRange(for: listItem) else {
            return descendInto(listItem)
        }

        // Determine nesting depth
        var depth = 0
        var parent = listItem.parent
        while parent != nil {
            if parent is ListItem { depth += 1 }
            parent = parent?.parent
        }

        let style = NSMutableParagraphStyle()
        let indent = CGFloat(16 + depth * 16)
        style.headIndent = indent
        style.firstLineHeadIndent = max(0, indent - 16)
        style.lineSpacing = theme.lineSpacing
        style.paragraphSpacing = 2

        ranges.append(StyledRange(range, [
            .paragraphStyle: style,
        ]))

        // Mark bullet/number prefix as syntax
        let sourceText = nsText.substring(with: range)
        let trimmed = sourceText.drop(while: { $0 == " " || $0 == "\t" })
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            let whitespaceLen = sourceText.count - trimmed.count
            let syntaxRange = NSRange(location: range.location + whitespaceLen, length: 2)
            if syntaxRange.location + syntaxRange.length <= nsText.length {
                addSyntaxRange(syntaxRange)
            }
        } else if let dotIndex = trimmed.firstIndex(of: "."),
                  trimmed[trimmed.startIndex..<dotIndex].allSatisfy(\.isNumber) {
            let whitespaceLen = sourceText.count - trimmed.count
            let numLen = trimmed.distance(from: trimmed.startIndex, to: dotIndex) + 2
            let syntaxRange = NSRange(
                location: range.location + whitespaceLen,
                length: min(numLen, range.length)
            )
            if syntaxRange.location + syntaxRange.length <= nsText.length {
                addSyntaxRange(syntaxRange)
            }
        }

        descendInto(listItem)
    }

    // MARK: - Inline Elements

    mutating func visitStrong(_ strong: Strong) {
        guard let range = nsRange(for: strong) else {
            return descendInto(strong)
        }

        let font: NSFont = (strong.parent is Emphasis) ? theme.boldItalicFont : theme.boldFont
        ranges.append(StyledRange(range, [.font: font]))

        if let prefix = syntaxPrefixRange(for: strong, prefixLength: 2) {
            addSyntaxRange(prefix)
        }
        if let suffix = syntaxSuffixRange(for: strong, suffixLength: 2) {
            addSyntaxRange(suffix)
        }

        descendInto(strong)
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) {
        guard let range = nsRange(for: emphasis) else {
            return descendInto(emphasis)
        }

        let font: NSFont = (emphasis.parent is Strong) ? theme.boldItalicFont : theme.italicFont
        ranges.append(StyledRange(range, [.font: font]))

        if let prefix = syntaxPrefixRange(for: emphasis, prefixLength: 1) {
            addSyntaxRange(prefix)
        }
        if let suffix = syntaxSuffixRange(for: emphasis, suffixLength: 1) {
            addSyntaxRange(suffix)
        }

        descendInto(emphasis)
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        guard let range = nsRange(for: inlineCode) else { return }

        ranges.append(StyledRange(range, [
            .font: theme.codeFont,
            .backgroundColor: theme.codeBackground,
        ]))

        if let prefix = syntaxPrefixRange(for: inlineCode, prefixLength: 1) {
            addSyntaxRange(prefix)
        }
        if let suffix = syntaxSuffixRange(for: inlineCode, suffixLength: 1) {
            addSyntaxRange(suffix)
        }
    }

    mutating func visitLink(_ link: Link) {
        guard let range = nsRange(for: link) else {
            return descendInto(link)
        }

        var attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        if let dest = link.destination {
            attrs[.link] = URL(string: dest)
        }
        ranges.append(StyledRange(range, attrs))

        // Mark the URL portion [text](url) — the (url) part as syntax
        let sourceText = nsText.substring(with: range)
        if let parenStart = sourceText.lastIndex(of: "(") {
            let parenOffset = sourceText.distance(from: sourceText.startIndex, to: parenStart)
            let syntaxRange = NSRange(
                location: range.location + parenOffset,
                length: range.length - parenOffset
            )
            if syntaxRange.location + syntaxRange.length <= nsText.length {
                addSyntaxRange(syntaxRange)
            }
        }

        descendInto(link)
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        guard let range = nsRange(for: strikethrough) else {
            return descendInto(strikethrough)
        }

        ranges.append(StyledRange(range, [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))

        if let prefix = syntaxPrefixRange(for: strikethrough, prefixLength: 2) {
            addSyntaxRange(prefix)
        }
        if let suffix = syntaxSuffixRange(for: strikethrough, suffixLength: 2) {
            addSyntaxRange(suffix)
        }

        descendInto(strikethrough)
    }

    mutating func visitImage(_ image: Image) {
        guard let range = nsRange(for: image) else { return }

        ranges.append(StyledRange(range, [
            .foregroundColor: NSColor.linkColor,
        ]))

        if let prefix = syntaxPrefixRange(for: image, prefixLength: 2) {
            addSyntaxRange(prefix)
        }
    }
}
