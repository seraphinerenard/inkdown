import SwiftUI
import WebKit

// MARK: - Weak message-handler proxy

/// WKUserContentController *strongly* retains its script-message handlers, which
/// would form config → controller → handler → coordinator → webView → config and
/// leak the whole web view. Routing through a weak proxy breaks that cycle.
private final class WeakScriptMessageProxy: NSObject, WKScriptMessageHandler {
    weak var target: PreviewWebView.Coordinator?
    init(_ target: PreviewWebView.Coordinator) { self.target = target }
    func userContentController(_ controller: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.handle(message)
    }
}

// MARK: - Preview web view

/// Renders Markdown to HTML in a WKWebView using the bundled markdown-it stack.
/// The shell page loads once; edits push new source over the JS bridge and the
/// DOM updates in place (scroll preserved, no reload).
struct PreviewWebView: NSViewRepresentable {
    let text: String
    var isDark: Bool
    /// Wired in Phase 3 for scroll sync; nil means preview→editor sync is inert.
    var bridge: EditorPreviewBridge?

    func makeNSView(context: Context) -> WKWebView {
        let coordinator = context.coordinator
        let proxy = WeakScriptMessageProxy(coordinator)

        let controller = WKUserContentController()
        for name in ["ready", "scrollSync", "revealEditor", "linkClicked"] {
            controller.add(proxy, name: name)
        }

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.setURLSchemeHandler(ResourceSchemeHandler(), forURLScheme: ResourceSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = coordinator
        webView.setValue(false, forKey: "drawsBackground")   // let CSS own the background
        webView.allowsMagnification = true

        coordinator.webView = webView
        coordinator.latestText = text
        coordinator.isDark = isDark
        coordinator.bridge = bridge
        bridge?.preview = coordinator

        let index = URL(string: "\(ResourceSchemeHandler.scheme)://preview/index.html")!
        webView.load(URLRequest(url: index))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.bridge = bridge
        bridge?.preview = context.coordinator
        context.coordinator.scheduleRender(text)
        context.coordinator.applyTheme(isDark)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        coordinator.cancel()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        weak var bridge: EditorPreviewBridge?

        var latestText = ""
        private var renderedText: String?
        private var isReady = false
        var isDark = false
        private var appliedDark: Bool?
        private var renderWork: DispatchWorkItem?

        // MARK: Rendering (debounced)

        func scheduleRender(_ text: String) {
            latestText = text
            renderWork?.cancel()
            let work = DispatchWorkItem { [weak self] in self?.flush() }
            renderWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
        }

        private func flush() {
            guard isReady, latestText != renderedText else { return }
            renderedText = latestText
            webView?.callAsyncJavaScript("window.MDPreview.render(md);",
                                         arguments: ["md": latestText],
                                         in: nil, in: .page)
        }

        func applyTheme(_ dark: Bool) {
            isDark = dark
            guard isReady, appliedDark != dark else { return }
            appliedDark = dark
            webView?.callAsyncJavaScript("window.MDPreview.setTheme(d);",
                                         arguments: ["d": dark], in: nil, in: .page)
        }

        func cancel() { renderWork?.cancel() }

        // MARK: Bridge messages (JS → Swift)

        func handle(_ message: WKScriptMessage) {
            switch message.name {
            case "ready":
                isReady = true
                appliedDark = nil
                applyTheme(isDark)
                renderedText = nil
                flush()
            case "linkClicked":
                if let href = (message.body as? [String: Any])?["href"] as? String,
                   let url = URL(string: href) {
                    NSWorkspace.shared.open(url)
                }
            case "scrollSync":
                if let line = (message.body as? [String: Any])?["line"] as? Int {
                    bridge?.previewDidScroll(toLine: line)
                }
            case "revealEditor":
                if let line = (message.body as? [String: Any])?["line"] as? Int {
                    bridge?.revealInEditor(line: line)
                }
            default:
                break
            }
        }

        // Scroll the preview to a source line (called by the bridge; Phase 3).
        func scrollPreview(toLine line: Int) {
            guard isReady else { return }
            webView?.callAsyncJavaScript("window.MDPreview.scrollToLine(l);",
                                         arguments: ["l": line], in: nil, in: .page)
        }

        func revealPreview(line: Int) {
            guard isReady else { return }
            webView?.callAsyncJavaScript("window.MDPreview.revealLine(l);",
                                         arguments: ["l": line], in: nil, in: .page)
        }

        // MARK: - Export to standalone HTML

        /// Read back the rendered DOM and wrap it with inlined CSS + fonts so the
        /// result opens anywhere with no external files.
        func exportStandaloneHTML(dark: Bool, completion: @escaping (String?) -> Void) {
            guard let webView else { completion(nil); return }
            webView.evaluateJavaScript("document.getElementById('content').innerHTML") { result, _ in
                let body = (result as? String) ?? ""
                let css = Self.exportCSS()
                let doc = """
                <!doctype html>
                <html\(dark ? " class=\"dark\"" : "")>
                <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Markdown Export</title>
                <style>\n\(css)\n</style>
                </head>
                <body class="markdown-body">\n\(body)\n</body>
                </html>
                """
                completion(doc)
            }
        }

        private static func exportCSS() -> String {
            guard let root = Bundle.module.resourceURL?.appendingPathComponent("preview") else { return "" }
            let styles = (try? String(contentsOf: root.appendingPathComponent("styles.css"))) ?? ""
            let katexRaw = (try? String(contentsOf: root.appendingPathComponent("katex.min.css"))) ?? ""
            let katex = inlineWoff2(katexRaw, fontsDir: root.appendingPathComponent("fonts"))
            return katex + "\n" + styles
        }

        /// Replace `url(fonts/X.woff2)` with base64 data URIs so math fonts travel
        /// with the file. Other format fallbacks (.woff/.ttf) are left as-is; the
        /// browser uses the woff2 data URI first and never requests them.
        private static func inlineWoff2(_ css: String, fontsDir: URL) -> String {
            guard let regex = try? NSRegularExpression(pattern: #"url\(fonts/([A-Za-z0-9_\-]+\.woff2)\)"#)
            else { return css }
            let ns = css as NSString
            var output = css
            let matches = regex.matches(in: css, range: NSRange(location: 0, length: ns.length))
            for match in matches.reversed() {   // reverse so earlier ranges stay valid
                let name = ns.substring(with: match.range(at: 1))
                guard let data = try? Data(contentsOf: fontsDir.appendingPathComponent(name)) else { continue }
                let replacement = "url(data:font/woff2;base64,\(data.base64EncodedString()))"
                output = (output as NSString).replacingCharacters(in: match.range, with: replacement)
            }
            return output
        }
    }
}
