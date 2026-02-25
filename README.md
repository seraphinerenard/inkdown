# Inkdown — The Markdown Editor macOS Deserves

<p align="center">
  <img src="icon.png" width="128" height="128" alt="Inkdown — Native macOS Markdown Editor">
</p>

<p align="center">
  <strong>A lightweight, native macOS Markdown editor with Typora-style inline WYSIWYG rendering.</strong><br>
  No Electron. No web views. No subscriptions. Just Markdown done right.
</p>

<p align="center">
  <a href="https://github.com/seraphinerenard/inkdown/releases/latest">Download for Mac (Apple Silicon)</a>
</p>

---

## What Is Inkdown?

Inkdown is a **free, open-source Markdown editor for macOS** built entirely in Swift and SwiftUI. It renders Markdown inline as you type — headings appear large, bold text appears bold, code appears monospaced — all without a split-pane preview. Syntax characters (`##`, `**`, `` ` ``) hide automatically when you're not editing that line.

Think Typora, but native to Mac, open source, and blazingly fast.

## Features

- **Inline WYSIWYG Rendering** — Markdown renders in place. No preview pane needed. What you see is what you get.
- **Syntax Auto-Hide** — Markdown syntax characters disappear when you move to a different line, reappear when you click back. Clean reading, full control when editing.
- **Native macOS App** — Built with SwiftUI and AppKit. Launches instantly, respects your system settings, and feels right at home on your Mac.
- **Dark Mode** — Follows your system appearance automatically. Beautiful in both light and dark.
- **File Tree Sidebar** — Open any folder and browse your Markdown files in a collapsible tree. Click to open.
- **Document-Based** — Opens `.md` files from Finder. Drag and drop. Double-click. It just works.
- **Clean Typography** — SF Pro for prose, SF Mono for code. Generous whitespace. Zero clutter.
- **Keyboard First** — Find and replace, undo/redo, all the shortcuts you expect.
- **Fast** — Sub-second launch. Handles large files with debounced parsing. No lag.
- **Truly Lightweight** — Under 2MB. No runtime dependencies. No frameworks to install.

## Supported Markdown

| Element | Syntax | Rendered |
|---------|--------|----------|
| Headings | `# H1` through `###### H6` | Cascading sizes (28pt → 14.5pt) |
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

### Option 1: Download the App

Download `Inkdown.app.zip` from [Releases](https://github.com/seraphinerenard/inkdown/releases/latest), unzip, and drag to `/Applications`.

> **Note:** Inkdown is currently built for **Apple Silicon** (M1/M2/M3/M4). Since the app is not notarized, you may need to right-click → Open on first launch.

### Option 2: Build from Source

Requires Xcode 16+ or the Swift 6.0 toolchain.

```bash
git clone https://github.com/seraphinerenard/inkdown.git
cd inkdown
swift build -c release
```

The binary will be at `.build/release/MarkdownEditor`. Copy it into an app bundle or run directly.

## Architecture

```
Sources/
├── MarkdownEditorApp.swift          — App entry point (DocumentGroup)
├── MarkdownDocument.swift           — FileDocument for .md read/write
├── ContentView.swift                — NavigationSplitView layout
├── Editor/
│   ├── MarkdownTextView.swift       — NSViewRepresentable wrapping NSTextView
│   ├── MarkdownStyler.swift         — AST-driven styled range generation
│   └── Theme.swift                  — Typography, colors, dark mode
└── Sidebar/
    ├── FileTreeView.swift           — Folder browser with OutlineGroup
    ├── FolderState.swift            — Observable folder state
    └── FileNode.swift               — Recursive file tree model
```

**Key design decisions:**

- **NSTextView** for the editor core — the only AppKit component that supports glyph-level control for syntax hiding
- **Apple's swift-markdown** for AST parsing — zero third-party dependencies beyond Apple's own library
- **O(1) UTF-8 → UTF-16 offset lookup table** for converting AST source locations to NSRange without linear scans
- **Active paragraph tracking** — syntax characters only visible in the line you're editing

## Dependencies

Just one: [swift-markdown](https://github.com/apple/swift-markdown) by Apple. That's it.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (arm64)

## Why Another Markdown Editor?

Most Markdown editors on Mac are either Electron wrappers (slow, heavy) or require subscriptions for basic functionality. Inkdown is none of that:

- **Not Electron** — Native Swift, native performance, native feel
- **Not a subscription** — Free and open source, forever
- **Not a split pane** — Inline rendering means your Markdown looks like the final output while you write
- **Not bloated** — No plugins, no themes marketplace, no cloud sync, no AI features. Just an editor that opens files and lets you write.

If you want a simple, fast, native Markdown editor that gets out of your way — this is it.

## License

MIT
