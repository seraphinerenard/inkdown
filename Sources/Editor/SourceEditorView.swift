import SwiftUI
import AppKit

// MARK: - Custom NSTextView subclass

/// A Markdown *source* editor: plain text in, plain text out. Paste is forced to
/// plain text so we never accumulate rich attributes — coloring is applied purely
/// as display-only temporary attributes by `SyntaxHighlighter`.
final class PlainPasteTextView: NSTextView {
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    // MARK: - Formatting shortcuts (VSCode-style)

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let chars = event.charactersIgnoringModifiers {
            switch chars {
            case "b": wrapSelection(with: "**"); return true
            case "i": wrapSelection(with: "*"); return true
            case "`": wrapSelection(with: "`"); return true
            case "k": insertLink(); return true
            default: break
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Toggle a wrapping delimiter (e.g. `**`) around the selection.
    func wrapSelection(with marker: String) {
        let sel = selectedRange()
        let ns = string as NSString
        let selected = ns.substring(with: sel)
        let mLen = (marker as NSString).length

        // Already wrapped → unwrap.
        if selected.count >= 2 * marker.count,
           selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let inner = String(selected.dropFirst(marker.count).dropLast(marker.count))
            guard shouldChangeText(in: sel, replacementString: inner) else { return }
            replaceCharacters(in: sel, with: inner)
            didChangeText()
            setSelectedRange(NSRange(location: sel.location, length: (inner as NSString).length))
            return
        }

        let wrapped = marker + selected + marker
        guard shouldChangeText(in: sel, replacementString: wrapped) else { return }
        replaceCharacters(in: sel, with: wrapped)
        didChangeText()
        setSelectedRange(NSRange(location: sel.location + mLen, length: sel.length))
    }

    /// Wrap the selection as a Markdown link `[text]()`, caret inside the parens.
    func insertLink() {
        let sel = selectedRange()
        let ns = string as NSString
        let replacement = "[\(ns.substring(with: sel))]()"
        guard shouldChangeText(in: sel, replacementString: replacement) else { return }
        replaceCharacters(in: sel, with: replacement)
        didChangeText()
        setSelectedRange(NSRange(location: sel.location + (replacement as NSString).length - 1, length: 0))
    }

    // MARK: - Smart list continuation

    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let lineRange = ns.lineRange(for: NSRange(location: selectedRange().location, length: 0))
        let line = ns.substring(with: lineRange)

        guard let info = MarkdownList.info(for: line) else {
            super.insertNewline(sender); return
        }
        if info.contentEmpty {
            // Enter on an empty item ends the list: clear the marker, plain newline.
            let markerRange = NSRange(location: lineRange.location, length: info.markerLength)
            if shouldChangeText(in: markerRange, replacementString: "") {
                replaceCharacters(in: markerRange, with: "")
                didChangeText()
            }
            super.insertNewline(sender)
            return
        }
        super.insertNewline(sender)
        insertText(info.continuation, replacementRange: selectedRange())
    }
}

// MARK: - NSViewRepresentable

/// Raw Markdown source editor (VSCode-style): the literal `**`, `#`, backticks stay
/// visible and are syntax-highlighted. Rendering happens in the separate preview pane.
struct SourceEditorView: NSViewRepresentable {
    @Binding var text: String
    /// Optional sync hub; when set, the editor reports scroll/cursor and can be driven back.
    var bridge: EditorPreviewBridge?

    func makeNSView(context: Context) -> NSScrollView {
        // Hand-built TextKit 1 stack — required for NSLayoutManager temporary attributes.
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = PlainPasteTextView(frame: .zero, textContainer: textContainer)

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        // Typography — one uniform base font; color comes from temporary attributes.
        textView.font = Theme.shared.codeFontForEditor
        textView.textColor = .textColor
        textView.backgroundColor = Theme.shared.editorBackground
        textView.insertionPointColor = .textColor
        textView.drawsBackground = true
        textView.defaultParagraphStyle = Theme.shared.defaultParagraphStyle

        // Source-editor behavior: plain text, no smart substitutions.
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false

        textView.textContainerInset = NSSize(width: 20, height: 16)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        // Wire the incremental highlighter as the storage delegate.
        let highlighter = context.coordinator.highlighter
        highlighter.layoutManager = layoutManager
        highlighter.textContainer = textContainer
        highlighter.textView = textView
        textStorage.delegate = highlighter

        textView.delegate = context.coordinator
        textView.string = text

        context.coordinator.textView = textView
        context.coordinator.textStorage = textStorage
        context.coordinator.bridge = bridge
        bridge?.editor = context.coordinator
        context.coordinator.observeScroll(scrollView)

        // Paint once the view has a real frame (visible range is known then).
        DispatchQueue.main.async { highlighter.rehighlight(textStorage) }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        // Only react to external/programmatic text changes; interactive edits are
        // already re-highlighted by the storage delegate as they happen.
        if textView.string != text {
            textView.string = text   // triggers the delegate → incremental re-highlight
            textView.setSelectedRange(NSRange(location: 0, length: 0))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SourceEditorView
        let highlighter = SyntaxHighlighter(theme: .shared)
        weak var textView: NSTextView?
        weak var bridge: EditorPreviewBridge?
        var textStorage: NSTextStorage?   // strong: pins the TextKit stack
        private var isProgrammaticScroll = false
        private var lastReportedTopLine = -1

        init(_ parent: SourceEditorView) {
            self.parent = parent
        }

        func observeScroll(_ scrollView: NSScrollView) {
            scrollView.contentView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(
                self, selector: #selector(viewportChanged),
                name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        }

        @objc private func viewportChanged() {
            highlighter.restyleViewport()
            guard !isProgrammaticScroll, let line = highlighter.topVisibleLine(),
                  line != lastReportedTopLine else { return }
            lastReportedTopLine = line
            bridge?.editorDidScroll(toTopLine: line)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView, textView.string.isEmpty == false else { return }
            let line = highlighter.line(forOffset: textView.selectedRange().location)
            bridge?.editorCursorMoved(toLine: line)
        }

        // MARK: - Driven by the bridge (preview → editor)

        /// Scroll so `line` sits at the top of the editor viewport.
        func scrollEditor(toLine line: Int) {
            guard let tv = textView, let lm = tv.layoutManager, let tc = tv.textContainer,
                  let clip = tv.enclosingScrollView?.contentView else { return }
            let offset = highlighter.offset(forLine: line)
            let glyphRange = lm.glyphRange(forCharacterRange: NSRange(location: offset, length: 0),
                                           actualCharacterRange: nil)
            let y = lm.boundingRect(forGlyphRange: glyphRange, in: tc).minY + tv.textContainerInset.height
            isProgrammaticScroll = true
            clip.scroll(to: NSPoint(x: 0, y: max(0, y)))
            tv.enclosingScrollView?.reflectScrolledClipView(clip)
            DispatchQueue.main.async { [weak self] in self?.isProgrammaticScroll = false }
        }

        /// Move the caret to `line`, scroll it into view, and focus the editor.
        func revealAndSelect(line: Int) {
            guard let tv = textView else { return }
            let range = NSRange(location: highlighter.offset(forLine: line), length: 0)
            tv.setSelectedRange(range)
            tv.scrollRangeToVisible(range)
            tv.window?.makeFirstResponder(tv)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
