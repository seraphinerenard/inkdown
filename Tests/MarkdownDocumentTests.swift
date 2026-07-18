import Testing
import AppKit
import UniformTypeIdentifiers
@testable import MarkdownEditor

@Suite("MarkdownDocument Tests")
struct MarkdownDocumentTests {
    @Test func defaultDocumentUsesSampleContent() {
        let doc = MarkdownDocument()
        #expect(!doc.text.isEmpty)
        #expect(doc.text == MarkdownDocument.sampleContent)
    }

    @Test func hasReadableContentTypes() {
        #expect(!MarkdownDocument.readableContentTypes.isEmpty)
    }

    @Test func roundTripsTextThroughFileWrapper() throws {
        let original = MarkdownDocument(text: "# Hello\n\nWorld")
        let wrapper = try original.fileWrapper(configuration: makeWriteConfiguration())
        let data = try #require(wrapper.regularFileContents)
        #expect(String(data: data, encoding: .utf8) == "# Hello\n\nWorld")
    }
}

// SwiftUI's `FileDocumentWriteConfiguration` has no public initializer; this
// mirrors its layout so tests can construct one. `MarkdownDocument.fileWrapper`
// never reads the configuration, so the placeholder fields are unobserved.
private struct WriteConfigurationLayout {
    let contentType: UTType
    let existingFile: FileWrapper?
}

private func makeWriteConfiguration() -> MarkdownDocument.WriteConfiguration {
    let layout = WriteConfigurationLayout(contentType: .plainText, existingFile: nil)
    return unsafeBitCast(layout, to: MarkdownDocument.WriteConfiguration.self)
}
