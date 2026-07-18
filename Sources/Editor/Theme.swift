import AppKit

/// Builds a light/dark-adaptive color from two RGB triples.
private func dynamicColor(light: (CGFloat, CGFloat, CGFloat),
                         dark: (CGFloat, CGFloat, CGFloat)) -> NSColor {
    NSColor(name: nil) { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let c = isDark ? dark : light
        return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1.0)
    }
}

struct Theme {
    static let shared = Theme()

    let bodyFontSize: CGFloat = 16
    let lineSpacing: CGFloat = 4

    let bodyFont: NSFont
    let boldFont: NSFont
    let italicFont: NSFont
    let boldItalicFont: NSFont
    let codeFont: NSFont
    /// Monospaced font for the raw-source editor pane (VSCode-style).
    let codeFontForEditor: NSFont

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
        dynamicColor(light: (0.99, 0.99, 0.99), dark: (0.11, 0.11, 0.12))
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
        codeFontForEditor = .monospacedSystemFont(ofSize: 13.5, weight: .regular)
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

    // MARK: - Source-editor token palette (VSCode-inspired, light/dark aware)

    let headingColor    = dynamicColor(light: (0.06, 0.38, 0.87), dark: (0.31, 0.76, 1.00))  // blue
    let emphasisColor   = dynamicColor(light: (0.44, 0.26, 0.76), dark: (0.77, 0.53, 0.75))  // purple
    let codeColor       = dynamicColor(light: (0.64, 0.20, 0.20), dark: (0.81, 0.57, 0.47))  // warm
    let linkColor       = dynamicColor(light: (0.04, 0.41, 0.85), dark: (0.31, 0.76, 1.00))  // link blue
    let linkURLColor    = dynamicColor(light: (0.30, 0.45, 0.60), dark: (0.42, 0.60, 0.74))  // muted
    let listColor       = dynamicColor(light: (0.75, 0.53, 0.00), dark: (0.84, 0.73, 0.49))  // amber
    let blockquoteColor = dynamicColor(light: (0.34, 0.42, 0.31), dark: (0.55, 0.66, 0.50))  // green-gray
    var punctColor: NSColor { syntaxColor }                                                  // markers

    func color(for kind: TokenKind) -> NSColor {
        switch kind {
        case .heading: return headingColor
        case .strong, .emphasis, .strikethrough: return emphasisColor
        case .inlineCode, .codeBlock: return codeColor
        case .linkText, .autolink: return linkColor
        case .linkURL: return linkURLColor
        case .listMarker, .taskMarker: return listColor
        case .blockquote, .frontMatter, .html: return blockquoteColor
        case .headingMarker, .codeFence, .linkPunct, .image,
             .thematicBreak, .tableDelim, .frontMatterFence:
            return punctColor
        }
    }
}
