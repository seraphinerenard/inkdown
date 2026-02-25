import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let markdown = UTType(
        importedAs: "net.daringfireball.markdown",
        conformingTo: .plainText
    )
}

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }

    var text: String

    static let sampleContent = """
    # Welcome to Markdown Editor

    This is a **native macOS** Markdown editor with *inline WYSIWYG* rendering.

    ## Features

    - **Bold text** renders bold inline
    - *Italic text* renders italic inline
    - `inline code` renders in monospace
    - Headings render at different sizes

    ### Code Block

    ```swift
    struct ContentView: View {
        var body: some View {
            Text("Hello, world!")
        }
    }
    ```

    > Block quotes are indented and styled differently.
    > They can span multiple lines.

    ---

    Here is **bold**, *italic*, and `code` together in a paragraph. Try clicking different lines to see syntax appear and disappear.
    """

    init(text: String = sampleContent) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}
