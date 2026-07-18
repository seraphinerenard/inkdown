import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// VSCode-style side-by-side container: raw-source editor on the left, live
/// preview on the right, with a layout switcher (editor / split / preview) and
/// a word-count / reading-time status bar.
struct EditorPreviewView: View {
    @Binding var text: String
    let bridge: EditorPreviewBridge
    @Environment(\.colorScheme) private var colorScheme
    @State private var layout: Layout = .split

    enum Layout: String, CaseIterable, Identifiable {
        case editorOnly, split, previewOnly
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .editorOnly: return "doc.plaintext"
            case .split: return "rectangle.split.2x1"
            case .previewOnly: return "eye"
            }
        }
        var help: String {
            switch self {
            case .editorOnly: return "Editor only"
            case .split: return "Editor and preview"
            case .previewOnly: return "Preview only"
            }
        }
    }

    var body: some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) { statusBar }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Picker("Layout", selection: $layout) {
                        ForEach(Layout.allCases) { l in
                            Image(systemName: l.symbol).help(l.help).tag(l)
                        }
                    }
                    .pickerStyle(.segmented)
                    .help("Editor / Split / Preview")
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: exportHTML) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export as standalone HTML")
                }
            }
    }

    private func exportHTML() {
        bridge.exportHTML(dark: colorScheme == .dark) { html in
            guard let html else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.html]
            panel.nameFieldStringValue = "document.html"
            panel.canCreateDirectories = true
            if panel.runModal() == .OK, let url = panel.url {
                try? html.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch layout {
        case .editorOnly:
            SourceEditorView(text: $text, bridge: bridge)
        case .previewOnly:
            PreviewWebView(text: text, isDark: colorScheme == .dark, bridge: bridge)
        case .split:
            HSplitView {
                SourceEditorView(text: $text, bridge: bridge)
                    .frame(minWidth: 240)
                PreviewWebView(text: text, isDark: colorScheme == .dark, bridge: bridge)
                    .frame(minWidth: 240)
            }
        }
    }

    private var statusBar: some View {
        let stats = DocumentStats(text: text)
        return HStack(spacing: 12) {
            Spacer()
            Text("\(stats.words) words")
            Text("\(stats.characters) chars")
            Text("\(stats.readingMinutes) min read")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// Live document statistics for the status bar.
struct DocumentStats {
    let words: Int
    let characters: Int
    let readingMinutes: Int

    init(text: String) {
        // Single pass: count word-boundary transitions and characters together,
        // avoiding the intermediate `[Substring]` that `split` would allocate.
        var wordCount = 0
        var charCount = 0
        var inWord = false
        for ch in text {
            charCount += 1
            if ch.isWhitespace {
                inWord = false
            } else if !inWord {
                inWord = true
                wordCount += 1
            }
        }
        words = wordCount
        characters = charCount
        readingMinutes = max(1, Int((Double(wordCount) / 200.0).rounded()))
    }
}
