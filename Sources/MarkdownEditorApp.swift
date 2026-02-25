import SwiftUI

@main
struct MarkdownEditorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: 900, height: 650)
        .windowToolbarStyle(.unified(showsTitle: true))
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Bring the app to front when launched from terminal
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
