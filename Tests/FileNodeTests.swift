import Testing
import AppKit
@testable import MarkdownEditor

@Suite("FileNode Tests")
struct FileNodeTests {
    @Test func createsNodeFromFileURL() {
        let node = FileNode(url: URL(fileURLWithPath: "/tmp/test.md"))
        #expect(node.name == "test.md")
        #expect(!node.isDirectory)
        #expect(node.isMarkdown)
    }

    @Test func createsNodeFromDirectoryURL() {
        let node = FileNode(url: URL(fileURLWithPath: "/tmp/docs", isDirectory: true), isDirectory: true)
        #expect(node.isDirectory)
        #expect(!node.isMarkdown)
    }

    @Test func detectsMarkdownExtension() {
        #expect(FileNode(url: URL(fileURLWithPath: "/tmp/notes.markdown")).isMarkdown)
    }

    @Test func nonMarkdownFileIsNotMarkdown() {
        #expect(!FileNode(url: URL(fileURLWithPath: "/tmp/code.swift")).isMarkdown)
    }
}
