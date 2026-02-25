import SwiftUI
import AppKit

// MARK: - Custom NSTextView subclass

/// Overrides paste to always insert plain text (we're a Markdown editor, not a rich text editor).
/// Also resets typing attributes to defaults so new text gets the body font.
class PlainPasteTextView: NSTextView {
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override var typingAttributes: [NSAttributedString.Key: Any] {
        get {
            // Always use default body attributes for newly typed text.
            // NSTextView tries to inherit attributes from adjacent text,
            // which would carry heading/bold/code styles forward.
            var attrs = Theme.shared.defaultAttributes
            // Preserve paragraph style from current position if set
            if let ps = super.typingAttributes[.paragraphStyle] {
                attrs[.paragraphStyle] = ps
            }
            return attrs
        }
        set {
            // Ignore external attempts to set typing attributes
        }
    }
}

// MARK: - NSViewRepresentable

struct MarkdownTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        // Build the text system manually so we can use our custom NSTextView subclass.
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true

        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textView = PlainPasteTextView(frame: .zero, textContainer: textContainer)

        let scrollView = NSScrollView()
        scrollView.documentView = textView

        // Typography
        textView.font = Theme.shared.bodyFont
        textView.textColor = .textColor
        textView.backgroundColor = Theme.shared.editorBackground
        textView.insertionPointColor = .textColor
        textView.drawsBackground = true

        // Behavior — must be true for attributed string styling to persist
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false

        // Layout — generous padding for clean look
        textView.textContainerInset = NSSize(width: 48, height: 24)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true

        // Scroll view styling
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        textView.delegate = context.coordinator
        textView.string = text

        context.coordinator.textView = textView
        context.coordinator.applyMarkdownStyling()

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
            // Reset selection to start — old ranges may be out of bounds for new text
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            context.coordinator.applyMarkdownStyling()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownTextView
        weak var textView: NSTextView?
        private let styler = MarkdownStyler(theme: .shared)
        private var activeParagraphRange = NSRange(location: 0, length: 0)
        private var styleWorkItem: DispatchWorkItem?
        private var isApplyingStyling = false

        init(_ parent: MarkdownTextView) {
            self.parent = parent
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            // Guard against re-entrant calls from our own attribute modifications
            guard !isApplyingStyling else { return }
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string

            // Debounce for large documents
            styleWorkItem?.cancel()
            if textView.string.count < 50_000 {
                applyMarkdownStyling()
            } else {
                let workItem = DispatchWorkItem { [weak self] in
                    self?.applyMarkdownStyling()
                }
                styleWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingStyling else { return }
            guard let textView = textView else { return }
            updateActiveParagraph(textView)
        }

        // MARK: - Markdown Styling

        func applyMarkdownStyling() {
            guard let textView = textView,
                  let storage = textView.textStorage else { return }

            let text = textView.string
            guard !text.isEmpty else { return }

            isApplyingStyling = true
            defer { isApplyingStyling = false }

            let fullRange = NSRange(location: 0, length: storage.length)

            storage.beginEditing()

            // Reset to default styling
            storage.setAttributes(Theme.shared.defaultAttributes, range: fullRange)

            // Parse and apply markdown attributes
            let styledRanges = styler.styledRanges(for: text)
            for styled in styledRanges {
                guard styled.nsRange.location >= 0,
                      styled.nsRange.location + styled.nsRange.length <= storage.length else {
                    continue
                }
                storage.addAttributes(styled.attributes, range: styled.nsRange)
            }

            // Hide syntax everywhere, then show in active paragraph
            hideSyntax(in: fullRange, storage: storage)
            if activeParagraphRange.length > 0,
               activeParagraphRange.location + activeParagraphRange.length <= storage.length {
                showSyntax(in: activeParagraphRange, storage: storage)
            }

            storage.endEditing()
        }

        // MARK: - Cursor Tracking + Syntax Hiding

        private func updateActiveParagraph(_ textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let nsString = textView.string as NSString
            guard nsString.length > 0 else { return }

            let cursorLocation = textView.selectedRange().location
            let clampedLocation = min(cursorLocation, nsString.length - 1)
            guard clampedLocation >= 0 else { return }

            let newRange = nsString.paragraphRange(
                for: NSRange(location: clampedLocation, length: 0)
            )

            if !NSEqualRanges(newRange, activeParagraphRange) {
                let oldRange = activeParagraphRange
                activeParagraphRange = newRange

                isApplyingStyling = true
                defer { isApplyingStyling = false }

                storage.beginEditing()

                // Hide syntax in old paragraph
                if oldRange.length > 0,
                   oldRange.location + oldRange.length <= storage.length {
                    hideSyntax(in: oldRange, storage: storage)
                }

                // Show syntax in new paragraph
                if newRange.length > 0,
                   newRange.location + newRange.length <= storage.length {
                    showSyntax(in: newRange, storage: storage)
                }

                storage.endEditing()
            }
        }

        private func hideSyntax(in range: NSRange, storage: NSTextStorage) {
            let clampedRange = NSIntersectionRange(range, NSRange(location: 0, length: storage.length))
            guard clampedRange.length > 0 else { return }

            storage.enumerateAttribute(.markdownSyntax, in: clampedRange) { value, attrRange, _ in
                guard value != nil else { return }
                storage.addAttributes([
                    .foregroundColor: NSColor.clear,
                ], range: attrRange)
            }
        }

        private func showSyntax(in range: NSRange, storage: NSTextStorage) {
            let clampedRange = NSIntersectionRange(range, NSRange(location: 0, length: storage.length))
            guard clampedRange.length > 0 else { return }

            storage.enumerateAttribute(.markdownSyntax, in: clampedRange) { value, attrRange, _ in
                guard value != nil else { return }
                storage.addAttributes([
                    .foregroundColor: Theme.shared.syntaxColor,
                ], range: attrRange)
            }
        }
    }
}
