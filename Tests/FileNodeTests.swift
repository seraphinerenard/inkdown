import Testing
import Foundation
@testable import MarkdownEditor

@Suite("FileNode Tests")
struct FileNodeTests {
    @Test func createsNodeFromFileURL() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let node = FileNode(url: url)
        #expect(node.name == "test.md")
        #expect(!node.isDirectory)
        #expect(node.isMarkdown)
    }

    @Test func createsNodeFromDirectoryURL() {
        let url = URL(fileURLWithPath: "/tmp/docs", isDirectory: true)
        let node = FileNode(url: url, isDirectory: true)
        #expect(node.isDirectory)
        #expect(!node.isMarkdown)
    }

    @Test func detectsMarkdownExtension() {
        let url = URL(fileURLWithPath: "/tmp/notes.markdown")
        let node = FileNode(url: url)
        #expect(node.isMarkdown)
    }

    @Test func nonMarkdownFileIsNotMarkdown() {
        let url = URL(fileURLWithPath: "/tmp/code.swift")
        let node = FileNode(url: url)
        #expect(!node.isMarkdown)
    }
}
