import Testing
import AppKit
@testable import MarkdownEditor

@Suite("Theme Tests")
struct ThemeTests {
    @Test func headingFontsDecreaseInSize() {
        let t = Theme.shared
        #expect(t.headingFont(level: 1).pointSize > t.headingFont(level: 2).pointSize)
        #expect(t.headingFont(level: 2).pointSize > t.headingFont(level: 3).pointSize)
    }

    @Test func codeFontIsMonospaced() {
        #expect(Theme.shared.codeFont.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }

    @Test func editorFontIsMonospaced() {
        #expect(Theme.shared.codeFontForEditor.fontDescriptor.symbolicTraits.contains(.monoSpace))
    }

    @Test func defaultAttributesIncludeBodyFont() {
        let font = Theme.shared.defaultAttributes[.font] as? NSFont
        #expect(font != nil)
        #expect(font?.pointSize == 16)
    }

    @Test func headingLevelIsClampedTo1Through6() {
        let t = Theme.shared
        #expect(t.headingFont(level: 0).pointSize == t.headingFont(level: 1).pointSize)
        #expect(t.headingFont(level: 7).pointSize == t.headingFont(level: 6).pointSize)
    }

    @Test func tokenPaletteCoversAllKinds() {
        // A representative sample; color(for:) is an exhaustive switch so this
        // mostly guards against a nil/crash regression.
        let kinds: [TokenKind] = [.heading, .strong, .inlineCode, .linkText, .listMarker, .blockquote]
        for k in kinds {
            #expect(Theme.shared.color(for: k) != nil)
        }
    }
}
