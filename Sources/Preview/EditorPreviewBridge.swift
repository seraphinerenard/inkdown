import Foundation

/// Imperative hub for high-frequency editor↔preview sync events. Scroll ticks
/// call methods here directly rather than routing through SwiftUI state (which
/// would thrash the view graph at 100+ events/sec). The ownership lock prevents
/// the scroll-echo feedback loop between the two panes. Fully wired in Phase 3.
final class EditorPreviewBridge {
    enum Owner { case none, editor, preview }

    weak var editor: SourceEditorView.Coordinator?
    weak var preview: PreviewWebView.Coordinator?

    /// Which pane the user most recently drove; the other follows without echoing.
    var owner: Owner = .none
    var suppressUntil: Date = .distantPast

    private func claim(_ who: Owner) {
        owner = who
        suppressUntil = Date().addingTimeInterval(0.15)
    }

    private var suppressed: Bool { Date() < suppressUntil }

    // MARK: - Editor drives

    func editorDidScroll(toTopLine line: Int) {
        guard owner != .preview || !suppressed else { return }
        claim(.editor)
        preview?.scrollPreview(toLine: line)
    }

    func editorCursorMoved(toLine line: Int) {
        guard owner != .preview || !suppressed else { return }
        preview?.revealPreview(line: line)
    }

    // MARK: - Preview drives

    func previewDidScroll(toLine line: Int) {
        guard owner != .editor || !suppressed else { return }
        claim(.preview)
        editor?.scrollEditor(toLine: line)
    }

    func revealInEditor(line: Int) {
        editor?.revealAndSelect(line: line)
    }

    // MARK: - Export

    /// Produce a self-contained HTML document of the current preview.
    func exportHTML(dark: Bool, completion: @escaping (String?) -> Void) {
        guard let preview else { completion(nil); return }
        preview.exportStandaloneHTML(dark: dark, completion: completion)
    }
}
