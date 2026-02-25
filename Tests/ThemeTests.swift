import Testing
import AppKit
@testable import MarkdownEditor

@Suite("Theme Tests")
struct ThemeTests {
    @Test func headingFontsDecreaseInSize() {
        let theme = Theme.shared
        let h1 = theme.headingFont(level: 1).pointSize
        let h2 = theme.headingFont(level: 2).pointSize
        let h3 = theme.headingFont(level: 3).pointSize
        #expect(h1 > h2)
        #expect(h2 > h3)
    }

    @Test func codeFontIsMonospaced() {
        let theme = Theme.shared
        let descriptor = theme.codeFont.fontDescriptor
        #expect(descriptor.symbolicTraits.contains(.monoSpace))
    }

    @Test func defaultAttributesIncludeBodyFont() {
        let attrs = Theme.shared.defaultAttributes
        let font = attrs[.font] as? NSFont
        #expect(font != nil)
        #expect(font?.pointSize == 16)
    }

    @Test func headingLevelIsClampedTo1Through6() {
        let theme = Theme.shared
        let h0 = theme.headingFont(level: 0)
        let h1 = theme.headingFont(level: 1)
        let h7 = theme.headingFont(level: 7)
        let h6 = theme.headingFont(level: 6)
        #expect(h0.pointSize == h1.pointSize)
        #expect(h7.pointSize == h6.pointSize)
    }
}
