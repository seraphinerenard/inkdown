import Foundation

struct FileNode: Identifiable, Hashable {
    var id: URL { url }
    let url: URL
    let name: String
    let isDirectory: Bool
    var children: [FileNode]?

    var isMarkdown: Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }

    init(url: URL, isDirectory: Bool = false, children: [FileNode]? = nil) {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.children = children
    }

    static func == (lhs: FileNode, rhs: FileNode) -> Bool {
        lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func buildTree(at url: URL) -> [FileNode] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var nodes: [FileNode] = []

        for itemURL in contents {
            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDir {
                let children = buildTree(at: itemURL)
                // Only include directories that contain markdown files (directly or nested)
                if !children.isEmpty {
                    nodes.append(FileNode(url: itemURL, isDirectory: true, children: children))
                }
            } else {
                let ext = itemURL.pathExtension.lowercased()
                if ext == "md" || ext == "markdown" {
                    nodes.append(FileNode(url: itemURL))
                }
            }
        }

        // Directories first, then files, both alphabetical
        return nodes.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}
