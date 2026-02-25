import SwiftUI

struct FileTreeView: View {
    @Bindable var folderState: FolderState
    var onOpenFile: (URL) -> Void

    var body: some View {
        Group {
            if folderState.tree.isEmpty {
                emptyState
            } else {
                fileList
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("Open a Folder")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("File \u{2192} Open Folder")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileList: some View {
        List(selection: $folderState.selectedFile) {
            if let rootName = folderState.rootURL?.lastPathComponent {
                Section(rootName) {
                    OutlineGroup(folderState.tree, children: \.children) { node in
                        FileRow(node: node)
                            .tag(node.url)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: folderState.selectedFile) { _, newValue in
            if let url = newValue, !url.hasDirectoryPath {
                onOpenFile(url)
            }
        }
    }
}

private struct FileRow: View {
    let node: FileNode

    var body: some View {
        Label {
            Text(node.name)
                .lineLimit(1)
        } icon: {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.text")
                .foregroundStyle(node.isDirectory ? .blue : .secondary)
        }
    }
}
