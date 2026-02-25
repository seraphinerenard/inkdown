import AppKit

struct Theme {
    static let shared = Theme()

    let bodyFontSize: CGFloat = 16
    let lineSpacing: CGFloat = 4

    let bodyFont: NSFont
    let boldFont: NSFont
    let italicFont: NSFont
    let boldItalicFont: NSFont
    let codeFont: NSFont

    let headingSizes: [CGFloat] = [28, 24, 20, 18, 16, 14.5]

    let syntaxColor: NSColor = .tertiaryLabelColor

    var codeBackground: NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 1.0, alpha: 0.06)
            } else {
                return NSColor(white: 0.0, alpha: 0.04)
            }
        }
    }

    var editorBackground: NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
            } else {
                return NSColor(white: 0.99, alpha: 1.0)
            }
        }
    }

    var blockquoteBar: NSColor {
        NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(white: 0.35, alpha: 1.0)
            } else {
                return NSColor(white: 0.75, alpha: 1.0)
            }
        }
    }

    var defaultAttributes: [NSAttributedString.Key: Any] {
        [
            .font: bodyFont,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: defaultParagraphStyle,
        ]
    }

    var defaultParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        return style
    }

    init() {
        bodyFont = .systemFont(ofSize: bodyFontSize, weight: .regular)
        boldFont = .systemFont(ofSize: bodyFontSize, weight: .bold)
        italicFont = NSFontManager.shared.convert(
            .systemFont(ofSize: bodyFontSize), toHaveTrait: .italicFontMask)
        boldItalicFont = NSFontManager.shared.convert(
            .systemFont(ofSize: bodyFontSize, weight: .bold), toHaveTrait: .italicFontMask)
        codeFont = .monospacedSystemFont(ofSize: bodyFontSize - 1, weight: .regular)
    }

    func headingFont(level: Int) -> NSFont {
        let clamped = max(1, min(level, 6))
        let size = headingSizes[clamped - 1]
        return .systemFont(ofSize: size, weight: .bold)
    }

    func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = lineSpacing
        style.paragraphSpacingBefore = level <= 2 ? 16 : 8
        style.paragraphSpacing = level <= 2 ? 8 : 4
        return [
            .font: headingFont(level: level),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: style,
        ]
    }
}
