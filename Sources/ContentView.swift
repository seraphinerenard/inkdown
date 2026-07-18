import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @State private var folderState = FolderState()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var bridge = EditorPreviewBridge()
    @State private var sidebarTab: SidebarTab = .files

    private enum SidebarTab: Hashable { case files, outline }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                Picker("Sidebar", selection: $sidebarTab) {
                    Image(systemName: "folder").tag(SidebarTab.files)
                    Image(systemName: "list.bullet.indent").tag(SidebarTab.outline)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(8)
                Divider()
                switch sidebarTab {
                case .files:
                    FileTreeView(folderState: folderState) { openFile($0) }
                case .outline:
                    OutlineView(text: document.text) { bridge.revealInEditor(line: $0) }
                }
            }
            .frame(minWidth: 200)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 400)
        } detail: {
            EditorPreviewView(text: $document.text, bridge: bridge)
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
