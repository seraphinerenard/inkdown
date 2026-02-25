import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @State private var folderState = FolderState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            FileTreeView(folderState: folderState) { url in
                openFile(url)
            }
            .frame(minWidth: 180)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 350)
        } detail: {
            MarkdownTextView(text: $document.text)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openFolder()
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Open a folder to browse files")
            }
        }
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing Markdown files"

        if panel.runModal() == .OK, let url = panel.url {
            folderState.openFolder(url)
            columnVisibility = .all
        }
    }

    private func openFile(_ url: URL) {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }
        document.text = text
    }
}
