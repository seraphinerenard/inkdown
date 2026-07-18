import Testing
@testable import MarkdownEditor

@Suite("Editing Logic Tests")
struct EditingLogicTests {

    // MARK: - Smart list continuation

    @Test func bulletContinuation() {
        #expect(MarkdownList.info(for: "- item\n")?.continuation == "- ")
    }
    @Test func emptyBulletDetected() {
        #expect(MarkdownList.info(for: "- \n")?.contentEmpty == true)
    }
    @Test func orderedIncrements() {
        #expect(MarkdownList.info(for: "1. foo\n")?.continuation == "2. ")
        #expect(MarkdownList.info(for: "3) x\n")?.continuation == "4) ")
    }
    @Test func indentPreserved() {
        #expect(MarkdownList.info(for: "  - a\n")?.continuation == "  - ")
    }
    @Test func checkedTaskContinuesUnchecked() {
        #expect(MarkdownList.info(for: "- [x] done\n")?.continuation == "- [ ] ")
    }
    @Test func plainLineIsNotAList() {
        #expect(MarkdownList.info(for: "plain text\n") == nil)
    }

    // MARK: - Outline

    @Test func outlineSkipsFencedHashes() {
        let hs = DocumentOutline.headings(from: "# A\n## B\n```\n# not a heading\n```\n### C\n")
        #expect(hs.map(\.title) == ["A", "B", "C"])
        #expect(hs.map(\.level) == [1, 2, 3])
        #expect(hs.map(\.line) == [0, 1, 5])
    }

    // MARK: - Stats

    @Test func documentStats() {
        let s = DocumentStats(text: "one two three four five")
        #expect(s.words == 5)
        #expect(s.readingMinutes == 1)
    }
}
