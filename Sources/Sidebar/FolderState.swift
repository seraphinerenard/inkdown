import SwiftUI

@Observable
class FolderState {
    var rootURL: URL?
    var tree: [FileNode] = []
    var selectedFile: URL?

    func openFolder(_ url: URL) {
        rootURL = url
        refreshTree()
    }

    func refreshTree() {
        guard let rootURL else {
            tree = []
            return
        }
        tree = FileNode.buildTree(at: rootURL)
    }
}
