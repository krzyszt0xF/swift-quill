import QuillCore
import QuillCoreTestSupport
import Testing

@Suite("Edge Case Tests")
struct EdgeCaseTests {

    @Test("Deeply nested list")
    func deeplyNestedList() {
        let markdown = """
        - a
          - b
            - c
              - d
                - e
                  - f
        """
        let blocks = MarkdownParser.live.parse(markdown)
        #expect(!blocks.isEmpty)

        guard case let .unorderedList(items) = blocks.first?.block else {
            Issue.record("Expected unorderedList, got \(String(describing: blocks.first))")
            return
        }
        #expect(items.count == 1)

        var depth = 1
        var currentItems = items
        while true {
            guard currentItems.count == 1,
                  let nestedItems = currentItems[0].children.compactMap({ node -> [Block.ListItem]? in
                      if case let .unorderedList(items) = node.block { return items }
                      return nil
                  }).first
            else { break }

            currentItems = nestedItems
            depth += 1
        }
        #expect(depth >= 5, "Expected at least 5 levels of nesting, got \(depth)")
    }

    @Test("Empty string returns empty array")
    func emptyString() {
        let blocks = MarkdownParser.live.parse("")
        #expect(blocks.isEmpty)
    }

    @Test("Full document integration")
    func fullDocumentIntegration() {
        let markdown = """
        # Project README

        This is the **introduction** paragraph with a [link](https://example.com).

        ## Features

        - Feature one
        - Feature two
        - Feature three

        > Important note about the project.

        ```python
        def hello():
            print("world")
        ```

        ---

        | Name | Value |
        | ---- | ----- |
        | key  | val   |

        Final paragraph.
        """

        let blocks = normalizedBlocks(MarkdownParser.live.parse(markdown))
        #expect(blocks.count == 9)

        guard case let .heading(h1Level, _) = blocks[0] else {
            Issue.record("Expected heading at [0], got \(blocks[0])")
            return
        }
        #expect(h1Level == 1)

        guard case .paragraph = blocks[1] else {
            Issue.record("Expected paragraph at [1], got \(blocks[1])")
            return
        }

        guard case let .heading(h2Level, _) = blocks[2] else {
            Issue.record("Expected heading at [2], got \(blocks[2])")
            return
        }
        #expect(h2Level == 2)

        guard case let .unorderedList(items) = blocks[3] else {
            Issue.record("Expected unorderedList at [3], got \(blocks[3])")
            return
        }
        #expect(items.count == 3)

        guard case .blockquote = blocks[4] else {
            Issue.record("Expected blockquote at [4], got \(blocks[4])")
            return
        }

        guard case let .codeBlock(language, _) = blocks[5] else {
            Issue.record("Expected codeBlock at [5], got \(blocks[5])")
            return
        }
        #expect(language == "python")

        guard case .thematicBreak = blocks[6] else {
            Issue.record("Expected thematicBreak at [6], got \(blocks[6])")
            return
        }

        guard case .table = blocks[7] else {
            Issue.record("Expected table at [7], got \(blocks[7])")
            return
        }

        guard case .paragraph = blocks[8] else {
            Issue.record("Expected paragraph at [8], got \(blocks[8])")
            return
        }
    }

    @Test("Long, long input")
    func veryLongInputProducesParagraphOutput() {
        let markdown = String(repeating: "word ", count: 10_000)
        let blocks = normalizedBlocks(MarkdownParser.live.parse(markdown))
        #expect(!blocks.isEmpty)

        guard case .paragraph = blocks.first else {
            Issue.record("Expected paragraph for long input, got \(String(describing: blocks.first))")
            return
        }
    }

    @Test("Mixed unclosed elements")
    func mixedUnclosedElements() {
        let markdown = "# Heading\n**unclosed bold\n```\nunclosed fence"
        let blocks = normalizedBlocks(MarkdownParser.live.parse(markdown))
        #expect(!blocks.isEmpty)

        guard case .heading = blocks.first else {
            Issue.record("Expected heading as first block, got \(String(describing: blocks.first))")
            return
        }
    }

    @Test("Multiple thematic breaks")
    func multipleThematicBreaks() {
        let blocks = normalizedBlocks(MarkdownParser.live.parse("---\n\n---\n\n---"))
        #expect(blocks == [.thematicBreak, .thematicBreak, .thematicBreak])
    }

    @Test("Unclosed code fence")
    func unclosedCodeFence() {
        let blocks = normalizedBlocks(MarkdownParser.live.parse("```\nsome code without closing fence\n"))
        #expect(!blocks.isEmpty)

        guard case .codeBlock = blocks.first else {
            Issue.record("Expected codeBlock, got \(String(describing: blocks.first))")
            return
        }
    }

    @Test("Unicode and emoji content")
    func unicodeAndEmoji() {
        let markdown = "# Emoji heading \u{1F389}\n\nParagraph with CJK: \u{4F60}\u{597D}\u{4E16}\u{754C}"
        let blocks = normalizedBlocks(MarkdownParser.live.parse(markdown))
        #expect(blocks.count == 2)

        guard case let .heading(level, content) = blocks[0] else {
            Issue.record("Expected heading, got \(blocks[0])")
            return
        }
        #expect(level == 1)

        let headingText = content.compactMap { inline -> String? in
            if case let .text(stringValue) = inline { return stringValue }
            return nil
        }.joined()
        #expect(headingText.contains("\u{1F389}"))

        guard case let .paragraph(paragraphContent) = blocks[1] else {
            Issue.record("Expected paragraph, got \(blocks[1])")
            return
        }
        let paragraphText = paragraphContent.compactMap { inline -> String? in
            if case let .text(stringValue) = inline { return stringValue }
            return nil
        }.joined()
        #expect(paragraphText.contains("\u{4F60}\u{597D}"))
    }

    @Test("Whitespace-only input")
    func whitespaceOnlyProducesNoMeaningfulBlocks() {
        let blocks = normalizedBlocks(MarkdownParser.live.parse("   \n\n  \t  "))
        let producedOnlyParagraphs = blocks.allSatisfy {
            if case .paragraph = $0 { return true }
            return false
        }

        #expect(producedOnlyParagraphs || blocks.isEmpty)
    }
}
