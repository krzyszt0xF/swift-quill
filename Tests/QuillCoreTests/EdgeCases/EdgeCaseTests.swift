import QuillCore
import QuillCoreTestSupport
import QuillSharedTestSupport
import Testing

@Suite("Edge Case Tests", .tags(.parsing))
struct EdgeCaseTests {

    @Test("Deeply nested list")
    func deeplyNestedList() throws {
        let blocks = normalizedBlocks(MarkdownParser.live.parse("""
        - a
          - b
            - c
              - d
                - e
                  - f
        """))
        let rootBlock = try #require(blocks.first)
        let rootItems = unorderedListItems(from: rootBlock)
        let items = try #require(rootItems)
        #expect(items.count == 1)

        var depth = 1
        var currentItems = items
        while true {
            guard
                currentItems.count == 1,
                let firstItem = currentItems.first,
                let nestedItems = firstItem.children.compactMap({ unorderedListItems(from: $0.block) }).first
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
    func fullDocumentIntegration() throws {
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

        let firstBlock = try requireBlock(at: 0, from: blocks)
        let secondBlock = try requireBlock(at: 1, from: blocks)
        let thirdBlock = try requireBlock(at: 2, from: blocks)
        let fourthBlock = try requireBlock(at: 3, from: blocks)
        let fifthBlock = try requireBlock(at: 4, from: blocks)
        let sixthBlock = try requireBlock(at: 5, from: blocks)
        let seventhBlock = try requireBlock(at: 6, from: blocks)
        let eighthBlock = try requireBlock(at: 7, from: blocks)
        let ninthBlock = try requireBlock(at: 8, from: blocks)

        let firstHeading = headingDetails(from: firstBlock)
        let (h1Level, _) = try #require(firstHeading)
        #expect(h1Level == 1)

        try #require(isParagraph(secondBlock))

        let secondHeading = headingDetails(from: thirdBlock)
        let (h2Level, _) = try #require(secondHeading)
        #expect(h2Level == 2)

        let listItems = unorderedListItems(from: fourthBlock)
        let items = try #require(listItems)
        #expect(items.count == 3)

        try #require(isBlockquote(fifthBlock))

        let codeBlock = codeBlockDetails(from: sixthBlock)
        let (language, _) = try #require(codeBlock)
        #expect(language == "python")

        try #require(isThematicBreak(seventhBlock))

        try #require(isTable(eighthBlock))

        try #require(isParagraph(ninthBlock))
    }

    @Test("Long, long input")
    func veryLongInputProducesParagraphOutput() throws {
        let markdown = String(repeating: "word ", count: 10_000)
        let blocks = normalizedBlocks(MarkdownParser.live.parse(markdown))
        let firstBlock = try #require(blocks.first)
        try #require(isParagraph(firstBlock))
    }

    @Test("Mixed unclosed elements")
    func mixedUnclosedElements() throws {
        let markdown = "# Heading\n**unclosed bold\n```\nunclosed fence"
        let blocks = normalizedBlocks(MarkdownParser.live.parse(markdown))
        let firstBlock = try #require(blocks.first)
        try #require(headingDetails(from: firstBlock) != nil)
    }

    @Test("Multiple thematic breaks")
    func multipleThematicBreaks() {
        let blocks = normalizedBlocks(MarkdownParser.live.parse("---\n\n---\n\n---"))
        #expect(blocks == [.thematicBreak, .thematicBreak, .thematicBreak])
    }

    @Test("Unclosed code fence")
    func unclosedCodeFence() throws {
        let blocks = normalizedBlocks(MarkdownParser.live.parse("```\nsome code without closing fence\n"))
        let firstBlock = try #require(blocks.first)
        try #require(codeBlockDetails(from: firstBlock) != nil)
    }

    @Test("Unicode and emoji content")
    func unicodeAndEmoji() throws {
        let markdown = "# Emoji heading \u{1F389}\n\nParagraph with CJK: \u{4F60}\u{597D}\u{4E16}\u{754C}"
        let blocks = normalizedBlocks(MarkdownParser.live.parse(markdown))
        #expect(blocks.count == 2)

        let firstBlock = try requireBlock(at: 0, from: blocks)
        let secondBlock = try requireBlock(at: 1, from: blocks)
        let heading = headingDetails(from: firstBlock)
        let (level, content) = try #require(heading)
        #expect(level == 1)

        let headingText = content.compactMap { inline -> String? in
            if case let .text(stringValue) = inline { return stringValue }
            return nil
        }.joined()
        #expect(headingText.contains("\u{1F389}"))

        let paragraph = paragraphInlines(from: secondBlock)
        let paragraphInlines = try #require(paragraph)
        let paragraphText = paragraphInlines.compactMap { inline -> String? in
            if case let .text(stringValue) = inline { return stringValue }
            return nil
        }.joined()
        #expect(paragraphText.contains("\u{4F60}\u{597D}"))
    }

    @Test("Whitespace-only input")
    func whitespaceOnlyProducesNoMeaningfulBlocks() {
        let blocks = normalizedBlocks(MarkdownParser.live.parse("   \n\n  \t  "))
        #expect(blocks.isEmpty || blocks.allSatisfy(isParagraph))
    }
}

private extension EdgeCaseTests {
    func codeBlockDetails(from block: Block) -> (String?, String)? {
        guard case let .codeBlock(language, code) = block else { return nil }
        return (language, code)
    }

    func headingDetails(from block: Block) -> (Int, [Inline])? {
        guard case let .heading(level, content) = block else { return nil }
        return (level, content)
    }

    func isBlockquote(_ block: Block) -> Bool {
        if case .blockquote = block { return true }
        return false
    }

    func isParagraph(_ block: Block) -> Bool {
        if case .paragraph = block { return true }
        return false
    }

    func isTable(_ block: Block) -> Bool {
        if case .table = block { return true }
        return false
    }

    func isThematicBreak(_ block: Block) -> Bool {
        if case .thematicBreak = block { return true }
        return false
    }

    func paragraphInlines(from block: Block) -> [Inline]? {
        guard case let .paragraph(content) = block else { return nil }
        return content
    }

    func requireBlock(at index: Int, from blocks: [Block]) throws -> Block {
        let block = blocks.indices.contains(index) ? blocks[index] : nil
        return try #require(block)
    }

    func unorderedListItems(from block: Block) -> [Block.ListItem]? {
        guard case let .unorderedList(items) = block else { return nil }
        return items
    }
}
