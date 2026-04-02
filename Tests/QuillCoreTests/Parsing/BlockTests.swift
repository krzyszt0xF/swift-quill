import QuillCore
import QuillCoreTestSupport
import QuillSharedTestSupport
import Testing

@Suite("Block Tests", .tags(.parsing))
struct BlockTests {
    // MARK: - Headings

    static let headingCases: [BlockTestCase] = [
        BlockTestCase(
            name: "H1 basic",
            markdown: "# Title",
            expected: [.heading(level: 1, content: [.text("Title")])]
        ),
        BlockTestCase(
            name: "H3 with bold content",
            markdown: "### **Bold** heading",
            expected: [.heading(level: 3, content: [.strong([.text("Bold")]), .text(" heading")])]
        ),
        BlockTestCase(
            name: "H6 max level",
            markdown: "###### Deepest",
            expected: [.heading(level: 6, content: [.text("Deepest")])]
        ),
    ]

    @Test("Headings", arguments: headingCases)
    func headings(_ testCase: BlockTestCase) {
        let blocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        #expect(blocks.canonicalBlocks() == testCase.expected.canonicalBlocks())
    }

    // MARK: - Paragraphs

    static let paragraphCases: [BlockTestCase] = [
        BlockTestCase(
            name: "Plain text",
            markdown: "Hello world",
            expected: [.paragraph(content: [.text("Hello world")])]
        ),
        BlockTestCase(
            name: "Mixed inline styles",
            markdown: "Normal **bold** and *italic* text",
            expected: [.paragraph(content: [
                .text("Normal "),
                .strong([.text("bold")]),
                .text(" and "),
                .emphasis([.text("italic")]),
                .text(" text"),
            ])]
        ),
    ]

    @Test("Paragraphs", arguments: paragraphCases)
    func paragraphs(_ testCase: BlockTestCase) {
        let blocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        #expect(blocks.canonicalBlocks() == testCase.expected.canonicalBlocks())
    }

    // MARK: - Code Blocks

    static let codeBlockCases: [BlockTestCase] = [
        BlockTestCase(
            name: "Fenced with language",
            markdown: "```swift\nlet x = 1\n```",
            expected: [.codeBlock(language: "swift", code: "let x = 1\n")]
        ),
        BlockTestCase(
            name: "Fenced without language",
            markdown: "```\nhello\n```",
            expected: [.codeBlock(language: nil, code: "hello\n")]
        ),
        BlockTestCase(
            name: "Indented code block",
            markdown: "    indented code\n    second line",
            expected: [.codeBlock(language: nil, code: "indented code\nsecond line\n")]
        ),
    ]

    @Test("Code blocks", arguments: codeBlockCases)
    func codeBlocks(_ testCase: BlockTestCase) {
        let blocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        #expect(blocks.canonicalBlocks() == testCase.expected.canonicalBlocks())
    }

    // MARK: - Blockquotes

    static let blockquoteCases: [BlockTestCase] = [
        BlockTestCase(
            name: "Simple quote",
            markdown: "> Hello world",
            expected: [Block.makeBlockquote(.paragraph(content: [.text("Hello world")]))]
        ),
        BlockTestCase(
            name: "Nested quote",
            markdown: "> Outer\n>> Inner",
            expected: [Block.makeBlockquote(
                .paragraph(content: [.text("Outer")]),
                Block.makeBlockquote(.paragraph(content: [.text("Inner")]))
            )]
        ),
    ]

    @Test("Blockquotes", arguments: blockquoteCases)
    func blockquotes(_ testCase: BlockTestCase) {
        let blocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        #expect(blocks.canonicalBlocks() == testCase.expected.canonicalBlocks())
    }

    // MARK: - Ordered Lists

    static let orderedListCases: [BlockTestCase] = [
        BlockTestCase(
            name: "Basic start=1",
            markdown: "1. First\n2. Second",
            expected: [.orderedList(startIndex: 1, items: [
                Block.ListItem(blocks: .paragraph(content: [.text("First")])),
                Block.ListItem(blocks: .paragraph(content: [.text("Second")])),
            ])]
        ),
        BlockTestCase(
            name: "Custom start index",
            markdown: "3. Third\n4. Fourth",
            expected: [.orderedList(startIndex: 3, items: [
                Block.ListItem(blocks: .paragraph(content: [.text("Third")])),
                Block.ListItem(blocks: .paragraph(content: [.text("Fourth")])),
            ])]
        ),
        BlockTestCase(
            name: "Nested list inside item",
            markdown: "1. Outer\n   - Inner bullet",
            expected: [.orderedList(startIndex: 1, items: [
                Block.ListItem(
                    blocks: .paragraph(content: [.text("Outer")]),
                    .unorderedList(items: [
                        Block.ListItem(blocks: .paragraph(content: [.text("Inner bullet")]))
                    ]),
                ),
            ])]
        ),
    ]

    @Test("Ordered lists", arguments: orderedListCases)
    func orderedLists(_ testCase: BlockTestCase) {
        let blocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        #expect(blocks.canonicalBlocks() == testCase.expected.canonicalBlocks())
    }

    // MARK: - Unordered Lists

    static let unorderedListCases: [BlockTestCase] = [
        BlockTestCase(
            name: "Basic bullets",
            markdown: "- Apple\n- Banana",
            expected: [.unorderedList(items: [
                Block.ListItem(blocks: .paragraph(content: [.text("Apple")])),
                Block.ListItem(blocks: .paragraph(content: [.text("Banana")])),
            ])]
        ),
        BlockTestCase(
            name: "Task list items",
            markdown: "- [x] Done\n- [ ] Todo",
            expected: [.unorderedList(items: [
                Block.ListItem(checkbox: .checked, blocks: .paragraph(content: [.text("Done")])),
                Block.ListItem(checkbox: .unchecked, blocks: .paragraph(content: [.text("Todo")])),
            ])]
        ),
        BlockTestCase(
            name: "List with code block inside item",
            markdown: "- Item\n\n  ```\n  code\n  ```",
            expected: [.unorderedList(items: [
                Block.ListItem(
                    blocks: .paragraph(content: [.text("Item")]),
                    .codeBlock(language: nil, code: "code\n"),
                ),
            ])]
        ),
    ]

    @Test("Unordered lists", arguments: unorderedListCases)
    func unorderedLists(_ testCase: BlockTestCase) {
        let blocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        #expect(blocks.canonicalBlocks() == testCase.expected.canonicalBlocks())
    }

    // MARK: - Thematic Breaks

    static let thematicBreakCases: [BlockTestCase] = [
        BlockTestCase(
            name: "Dashes ---",
            markdown: "---",
            expected: [.thematicBreak]
        ),
        BlockTestCase(
            name: "Asterisks ***",
            markdown: "***",
            expected: [.thematicBreak]
        ),
        BlockTestCase(
            name: "Underscores ___",
            markdown: "___",
            expected: [.thematicBreak]
        ),
    ]

    @Test("Thematic breaks", arguments: thematicBreakCases)
    func thematicBreaks(_ testCase: BlockTestCase) {
        let blocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        #expect(blocks.canonicalBlocks() == testCase.expected.canonicalBlocks())
    }

    // MARK: - Tables

    static let tableCases: [BlockTestCase] = [
        BlockTestCase(
            name: "Basic 2-column",
            markdown: "| A | B |\n| - | - |\n| 1 | 2 |",
            expected: [.table(
                columnAlignments: [nil, nil],
                header: Block.TableRow(cells: [
                    Block.TableCell(content: [.text("A")]),
                    Block.TableCell(content: [.text("B")]),
                ]),
                rows: [
                    Block.TableRow(cells: [
                        Block.TableCell(content: [.text("1")]),
                        Block.TableCell(content: [.text("2")]),
                    ]),
                ]
            )]
        ),
        BlockTestCase(
            name: "Table with column alignments",
            markdown: "| Left | Center | Right |\n| :--- | :---: | ---: |\n| a | b | c |",
            expected: [.table(
                columnAlignments: [.left, .center, .right],
                header: Block.TableRow(cells: [
                    Block.TableCell(content: [.text("Left")]),
                    Block.TableCell(content: [.text("Center")]),
                    Block.TableCell(content: [.text("Right")]),
                ]),
                rows: [
                    Block.TableRow(cells: [
                        Block.TableCell(content: [.text("a")]),
                        Block.TableCell(content: [.text("b")]),
                        Block.TableCell(content: [.text("c")]),
                    ]),
                ]
            )]
        ),
    ]

    @Test("Tables", arguments: tableCases)
    func tables(_ testCase: BlockTestCase) {
        let blocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        #expect(blocks.canonicalBlocks() == testCase.expected.canonicalBlocks())
    }

    // MARK: - HTML Blocks

    static let htmlBlockCases: [BlockTestCase] = [
        BlockTestCase(
            name: "Basic raw HTML block",
            markdown: "<div>\nhello\n</div>",
            expected: [.htmlBlock(rawHTML: "<div>\nhello\n</div>\n")]
        ),
    ]

    @Test("HTML blocks", arguments: htmlBlockCases)
    func htmlBlocks(_ testCase: BlockTestCase) {
        let blocks = MarkdownParser.live.parse(testCase.markdown).normalizedBlocks()
        #expect(blocks.canonicalBlocks() == testCase.expected.canonicalBlocks())
    }

    // MARK: - Multi-Block Document

    @Test("Multi-block document")
    func multiBlockDocument() throws {
        let markdown = """
        # Welcome

        This is a paragraph.

        ```swift
        let x = 42
        ```

        - Item one
        - Item two
        """
        
        let blocks = MarkdownParser.live.parse(markdown).normalizedBlocks()
        #expect(blocks.count == 4)

        let firstBlock = try requireBlock(at: 0, from: blocks)
        let secondBlock = try requireBlock(at: 1, from: blocks)
        let thirdBlock = try requireBlock(at: 2, from: blocks)
        let fourthBlock = try requireBlock(at: 3, from: blocks)
        let heading = headingDetails(from: firstBlock)
        let (level, content) = try #require(heading)
        #expect(level == 1)
        #expect(content == [.text("Welcome")])

        let paragraph = paragraphInlines(from: secondBlock)
        let pContent = try #require(paragraph)
        #expect(pContent == [.text("This is a paragraph.")])

        let codeBlock = codeBlockDetails(from: thirdBlock)
        let (lang, code) = try #require(codeBlock)
        #expect(lang == "swift")
        #expect(code == "let x = 42\n")

        let listItems = unorderedListItems(from: fourthBlock)
        let items = try #require(listItems)
        #expect(items.count == 2)
    }
}

private extension BlockTests {
    func codeBlockDetails(from block: Block) -> (String?, String)? {
        guard case let .codeBlock(language, code) = block else { return nil }
        return (language, code)
    }

    func headingDetails(from block: Block) -> (Int, [Inline])? {
        guard case let .heading(level, content) = block else { return nil }
        return (level, content)
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

// MARK: - Test Case Type

struct BlockTestCase: Sendable {
    let name: String
    let markdown: String
    let expected: [Block]
}

extension BlockTestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}
