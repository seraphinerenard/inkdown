import WebKit

/// Serves the bundled preview assets to the WKWebView over a custom `mdassets://`
/// scheme. A real, stable origin (rather than `file://`) lets KaTeX fonts, the
/// strict CSP, and Mermaid behave exactly as they would over https — fully offline.
final class ResourceSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "mdassets"

    /// Root of the copied `preview` resource tree inside the app bundle.
    private let root = Bundle.module.resourceURL

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let root, let url = task.request.url else {
            task.didFailWithError(URLError(.badURL)); return
        }
        // mdassets://preview/app.js  ->  <bundle>/preview/app.js
        let relative = (url.host ?? "") + url.path
        let fileURL = root.appendingPathComponent(relative).standardizedFileURL

        guard fileURL.path.hasPrefix(root.standardizedFileURL.path),   // path-traversal guard
              let data = try? Data(contentsOf: fileURL) else {
            task.didFailWithError(URLError(.fileDoesNotExist)); return
        }

        let response = HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": Self.mimeType(for: fileURL.pathExtension),
                           "Content-Length": String(data.count)])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js": return "text/javascript; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "json": return "application/json; charset=utf-8"
        case "woff2": return "font/woff2"
        case "woff": return "font/woff"
        case "ttf": return "font/ttf"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        default: return "application/octet-stream"
        }
    }
}
