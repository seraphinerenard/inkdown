# Inkdown

<p align="center">
  <img src="icon.png" width="128" height="128" alt="Inkdown icon">
</p>

<p align="center">
  A native macOS Markdown editor with inline WYSIWYG rendering.<br>
  <a href="https://github.com/seraphinerenard/inkdown/releases/latest">Download for Mac (Apple Silicon)</a>
</p>

---

## What is this?

Inkdown is a free, open-source Markdown editor for macOS, built in Swift and SwiftUI. It renders Markdown inline as you type. Headings appear large, bold text appears bold, code appears monospaced. There's no split-pane preview. Syntax characters (`##`, `**`, `` ` ``) hide when you're not editing that line and reappear when you click back.

If you've used Typora, you know the idea. This is similar, but native to macOS and open source.

## What it does

Markdown renders in place as you type. No preview pane. Syntax characters like `##` and `**` disappear when you move to another line, so you get a clean reading view while still having full control when editing.

There's a file tree sidebar for browsing folders of `.md` files. It opens files from Finder, supports drag and drop, follows your system dark mode setting, and launches in under a second. The whole app is under 2MB.

Typography is SF Pro for prose and SF Mono for code, with generous whitespace and minimal chrome.

## Supported Markdown

| Element | Syntax | Rendered |
|---------|--------|----------|
| Headings | `# H1` through `###### H6` | Cascading sizes (28pt to 14.5pt) |
| Bold | `**bold**` | **bold** |
| Italic | `*italic*` | *italic* |
| Bold Italic | `***both***` | ***both*** |
| Inline Code | `` `code` `` | `code` |
| Code Blocks | ` ``` ` fenced | Monospace with subtle background |
| Block Quotes | `> quote` | Indented, styled |
| Ordered Lists | `1. item` | Numbered |
| Unordered Lists | `- item` | Bulleted |
| Strikethrough | `~~text~~` | ~~text~~ |
| Links | `[text](url)` | Styled inline |
| Images | `![alt](url)` | Styled inline |
| Thematic Breaks | `---` | Horizontal rule |

## Install

### Download the app

Grab `Inkdown.app.zip` from [Releases](https://github.com/seraphinerenard/inkdown/releases/latest), unzip it, and drag to `/Applications`.

Built for Apple Silicon (M1/M2/M3/M4). The app isn't notarized, so you'll need to right-click and choose Open on first launch.

### Build from source

Requires Xcode 16+ or the Swift 6.0 toolchain.

```bash
git clone https://github.com/seraphinerenard/inkdown.git
cd inkdown
swift build -c release
```

The binary ends up at `.build/release/MarkdownEditor`.

## How it works

```
Sources/
├── MarkdownEditorApp.swift          App entry point (DocumentGroup)
├── MarkdownDocument.swift           FileDocument for .md read/write
├── ContentView.swift                NavigationSplitView layout
├── Editor/
│   ├── MarkdownTextView.swift       NSViewRepresentable wrapping NSTextView
│   ├── MarkdownStyler.swift         AST-driven styled range generation
│   └── Theme.swift                  Typography, colors, dark mode
└── Sidebar/
    ├── FileTreeView.swift           Folder browser with OutlineGroup
    ├── FolderState.swift            Observable folder state
    └── FileNode.swift               Recursive file tree model
```

The editor uses NSTextView because it's the only AppKit component with glyph-level control, which is needed for hiding syntax characters. Markdown parsing is handled by Apple's [swift-markdown](https://github.com/apple/swift-markdown) library. There are no other external dependencies.

A precomputed UTF-8 to UTF-16 offset lookup table converts AST source locations to NSRange in O(1) instead of scanning the string each time. The editor tracks which paragraph your cursor is in and only shows syntax characters for that paragraph.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (arm64)

## License

MIT
