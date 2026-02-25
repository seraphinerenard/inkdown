import Testing
@testable import MarkdownEditor

@Suite("MarkdownDocument Tests")
struct MarkdownDocumentTests {
    @Test func defaultDocumentHasEmptyText() {
        let doc = MarkdownDocument()
        #expect(doc.text == "")
    }

    @Test func hasReadableContentTypes() {
        #expect(!MarkdownDocument.readableContentTypes.isEmpty)
    }

    @Test func roundTripsTextThroughFileWrapper() throws {
        let original = MarkdownDocument(text: "# Hello\n\nWorld")
        let wrapper = try original.fileWrapper(
            configuration: MarkdownDocument.WriteConfiguration(
                existingFile: nil, contentType: .plainText
            )
        )
        let data = wrapper.regularFileContents!
        let text = String(data: data, encoding: .utf8)!
        #expect(text == "# Hello\n\nWorld")
    }
}
