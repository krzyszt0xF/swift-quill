import QuillCore
import QuillCoreTestSupport
import QuillSharedTestSupport
import Testing

@Suite("BlockReducer", .tags(.streaming))
struct BlockReducerTests {
    // MARK: - Paragraphs

    @Test("Simple paragraph")
    func simpleParagraph() {
        let blocks = [
            ParserEvent.startParagraph, .text("Hello"), .endParagraph,
        ].reduceToBlocks()
        #expect(blocks == [.paragraph(content: [.text("Hello")])])
    }

    @Test("Bold text in paragraph")
    func boldText() {
        let blocks = [
            ParserEvent.startParagraph,
            .text("a "), .startStrong, .text("bold"), .endStrong,
            .endParagraph,
        ].reduceToBlocks()
        #expect(blocks == [.paragraph(content: [.text("a "), .strong([.text("bold")])])])
    }

    @Test("Multiple blocks")
    func multipleBlocks() {
        let blocks = [
            ParserEvent.startParagraph, .text("First"), .endParagraph,
            .startParagraph, .text("Second"), .endParagraph,
        ].reduceToBlocks()
        #expect(blocks.count == 2)
        #expect(blocks == [
            .paragraph(content: [.text("First")]),
            .paragraph(content: [.text("Second")]),
        ])
    }

    // MARK: - Headings

    @Test("Heading with level")
    func heading() {
        let blocks = [
            ParserEvent.startHeading(level: 2), .text("Title"), .endHeading,
        ].reduceToBlocks()
        #expect(blocks == [.heading(level: 2, content: [.text("Title")])])
    }

    // MARK: - Code Blocks

    @Test("Code block with language")
    func codeBlock() {
        let blocks = [
            ParserEvent.startCodeBlock(language: "swift"),
            .codeBlockText("let x = 1\n"),
            .codeBlockText("let y = 2\n"),
            .endCodeBlock,
        ].reduceToBlocks()
        #expect(blocks == [.codeBlock(language: "swift", code: "let x = 1\nlet y = 2\n")])
    }

    // MARK: - Lists

    @Test("Unordered list")
    func unorderedList() {
        let blocks = [
            ParserEvent.startList(ordered: false),
            .startListItem, .startParagraph, .text("item"), .endParagraph, .endListItem,
            .endList,
        ].reduceToBlocks()
        #expect(blocks.canonicalBlocks() == [Block.unorderedList(items: [
            Block.ListItem(blocks: .paragraph(content: [.text("item")])),
        ])].canonicalBlocks())
    }

    @Test("Ordered list")
    func orderedList() {
        let blocks = [
            ParserEvent.startList(ordered: true),
            .startListItem, .startParagraph, .text("first"), .endParagraph, .endListItem,
            .startListItem, .startParagraph, .text("second"), .endParagraph, .endListItem,
            .endList,
        ].reduceToBlocks()
        #expect(blocks.canonicalBlocks() == [Block.orderedList(startIndex: 1, items: [
            Block.ListItem(blocks: .paragraph(content: [.text("first")])),
            Block.ListItem(blocks: .paragraph(content: [.text("second")])),
        ])].canonicalBlocks())
    }

    @Test("Task list keeps checkbox state")
    func taskList() {
        let blocks = [
            ParserEvent.startList(ordered: false),
            .startTaskListItem(checkbox: .checked), .startParagraph, .text("done"), .endParagraph, .endListItem,
            .startTaskListItem(checkbox: .unchecked), .startParagraph, .text("pending"), .endParagraph, .endListItem,
            .endList,
        ].reduceToBlocks()
        #expect(blocks.canonicalBlocks() == [Block.unorderedList(items: [
            Block.ListItem(checkbox: .checked, blocks: .paragraph(content: [.text("done")])),
            Block.ListItem(checkbox: .unchecked, blocks: .paragraph(content: [.text("pending")])),
        ])].canonicalBlocks())
    }

    // MARK: - Blockquotes

    @Test("Blockquote with paragraph")
    func blockquote() {
        let blocks = [
            ParserEvent.startBlockQuote,
            .startParagraph, .text("quoted"), .endParagraph,
            .endBlockQuote,
        ].reduceToBlocks()
        #expect(blocks.canonicalBlocks() == [Block.makeBlockquote(.paragraph(content: [.text("quoted")]))].canonicalBlocks())
    }

    // MARK: - Thematic Break

    @Test("Thematic break")
    func thematicBreak() {
        let blocks = [ParserEvent.thematicBreak].reduceToBlocks()
        #expect(blocks == [.thematicBreak])
    }

    // MARK: - Tables

    @Test("Table with header and data row")
    func table() {
        let blocks = [
            ParserEvent.startTable,
            .tableAlignments([nil, nil]),
            .tableRow(["A", "B"]),
            .tableRow(["1", "2"]),
            .endTable,
        ].reduceToBlocks()
        #expect(blocks == [.table(
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
        )])
    }

    @Test("Table keeps streamed alignments")
    func tableAlignments() {
        let blocks = [
            ParserEvent.startTable,
            .tableAlignments([.left, .center, .right]),
            .tableRow(["A", "B", "C"]),
            .tableRow(["1", "2", "3"]),
            .endTable,
        ].reduceToBlocks()

        #expect(blocks == [.table(
            columnAlignments: [.left, .center, .right],
            header: Block.TableRow(cells: [
                Block.TableCell(content: [.text("A")]),
                Block.TableCell(content: [.text("B")]),
                Block.TableCell(content: [.text("C")]),
            ]),
            rows: [
                Block.TableRow(cells: [
                    Block.TableCell(content: [.text("1")]),
                    Block.TableCell(content: [.text("2")]),
                    Block.TableCell(content: [.text("3")]),
                ]),
            ]
        )])
    }

    @Test("Table parses inline cell content on freeze")
    func tableInlineParsing() {
        let blocks = [
            ParserEvent.startTable,
            .tableAlignments([nil, nil, nil]),
            .tableRow(["**bold**", "*italic*", "`code`"]),
            .endTable,
        ].reduceToBlocks()

        #expect(blocks == [.table(
            columnAlignments: [nil, nil, nil],
            header: Block.TableRow(cells: [
                Block.TableCell(content: [.strong([.text("bold")])]),
                Block.TableCell(content: [.emphasis([.text("italic")])]),
                Block.TableCell(content: [.code("code")]),
            ]),
            rows: []
        )])
    }

    // MARK: - Inline Nesting

    @Test("Nested inline: emphasis wrapping strong")
    func nestedInline() {
        let blocks = [
            ParserEvent.startParagraph,
            .startEmphasis, .startStrong, .text("both"), .endStrong, .endEmphasis,
            .endParagraph,
        ].reduceToBlocks()
        #expect(blocks == [.paragraph(content: [
            .emphasis([.strong([.text("both")])]),
        ])])
    }

    @Test("Inline code")
    func inlineCode() {
        let blocks = [
            ParserEvent.startParagraph,
            .startInlineCode, .text("code"), .endInlineCode,
            .endParagraph,
        ].reduceToBlocks()
        #expect(blocks == [.paragraph(content: [.code("code")])])
    }

    @Test("Link")
    func link() {
        let blocks = [
            ParserEvent.startParagraph,
            .startLink(destination: "url"), .text("click"), .endLink,
            .endParagraph,
        ].reduceToBlocks()
        #expect(blocks == [.paragraph(content: [
            .link(destination: "url", children: [.text("click")]),
        ])])
    }

    @Test("Strikethrough")
    func strikethrough() {
        let blocks = [
            ParserEvent.startParagraph,
            .startStrikethrough, .text("deleted"), .endStrikethrough,
            .endParagraph,
        ].reduceToBlocks()
        #expect(blocks == [.paragraph(content: [.strikethrough([.text("deleted")])])])
    }

    @Test("Image in paragraph")
    func image() {
        let blocks = [
            ParserEvent.startParagraph,
            .image(source: "url", title: "t", alt: "a"),
            .endParagraph,
        ].reduceToBlocks()
        #expect(blocks == [.paragraph(content: [
            .image(source: "url", title: "t", alt: [.text("a")]),
        ])])
    }

    // MARK: - Frozen Count

    @Test("Frozen count tracks closed blocks")
    func frozenCount() {
        var state = BlockReducer.ReducerState()
        for event: ParserEvent in [
            .startParagraph, .text("a"), .endParagraph,
            .startHeading(level: 1), .text("b"), .endHeading,
        ] {
            BlockReducer.apply(event, to: &state)
        }
        #expect(state.frozenCount == 2)
        #expect(state.blocks.count == 2)
    }

    @Test("Open paragraph materializes as mutable tail before close")
    func openParagraphMaterializesMutableTail() {
        var state = BlockReducer.ReducerState()

        BlockReducer.apply(.startParagraph, to: &state)
        BlockReducer.apply(.text("Hello"), to: &state)

        #expect(state.frozenCount == 0)
        #expect(state.blocks.count == 1)
        #expect(state.blocks.first?.block == .paragraph(content: [.text("Hello")]))
    }

    @Test("Open code block materializes as mutable tail before close")
    func openCodeBlockMaterializesMutableTail() {
        var state = BlockReducer.ReducerState()

        BlockReducer.apply(.startCodeBlock(language: "swift"), to: &state)
        BlockReducer.apply(.codeBlockText("let x = 1\n"), to: &state)

        #expect(state.frozenCount == 0)
        #expect(state.blocks.count == 1)
        #expect(state.blocks.first?.block == .codeBlock(language: "swift", code: "let x = 1\n"))
    }

    @Test("Open list item materializes inside mutable list tail")
    func openListMaterializesMutableTail() {
        var state = BlockReducer.ReducerState()

        BlockReducer.apply(.startList(ordered: false), to: &state)
        BlockReducer.apply(.startListItem, to: &state)
        BlockReducer.apply(.startParagraph, to: &state)
        BlockReducer.apply(.text("item"), to: &state)

        #expect(state.frozenCount == 0)
        #expect(state.blocks.count == 1)
        #expect(state.blocks.map(\.block).canonicalBlocks() == [
            Block.unorderedList(items: [
                Block.ListItem(blocks: .paragraph(content: [.text("item")]))
            ])
        ].canonicalBlocks())
    }

    @Test("Open nested table keeps mutable list tail materialized before first row")
    func openNestedTableMaterializesMutableTail() {
        var state = BlockReducer.ReducerState()

        BlockReducer.apply(.startList(ordered: false), to: &state)
        BlockReducer.apply(.startListItem, to: &state)
        BlockReducer.apply(.startParagraph, to: &state)
        BlockReducer.apply(.text("item"), to: &state)
        BlockReducer.apply(.endParagraph, to: &state)
        BlockReducer.apply(.startTable, to: &state)
        BlockReducer.apply(.tableAlignments([nil, nil]), to: &state)

        #expect(state.frozenCount == 0)
        #expect(state.blocks.count == 1)
        #expect(state.blocks.map(\.block).canonicalBlocks() == [
            Block.unorderedList(items: [
                Block.ListItem(
                    blocks: .paragraph(content: [.text("item")]),
                    .table(
                        columnAlignments: [nil, nil],
                        header: Block.TableRow(cells: []),
                        rows: []
                    )
                )
            ])
        ].canonicalBlocks())
    }

    // MARK: - Determinism

    @Test("Deterministic: same events produce same blocks")
    func determinism() {
        let events: [ParserEvent] = [
            .startParagraph, .text("Hello"), .endParagraph,
            .startHeading(level: 2), .text("Title"), .endHeading,
            .thematicBreak,
        ]
        let blocks1 = events.reduceToBlocks()
        let blocks2 = events.reduceToBlocks()
        #expect(blocks1 == blocks2)
    }

    // MARK: - Nested Blocks

    @Test("List item with multiple blocks")
    func listItemWithMultipleBlocks() {
        let blocks = [
            ParserEvent.startList(ordered: false),
            .startListItem,
            .startParagraph, .text("text"), .endParagraph,
            .startCodeBlock(language: nil), .codeBlockText("code\n"), .endCodeBlock,
            .endListItem,
            .endList,
        ].reduceToBlocks()
        #expect(blocks.canonicalBlocks() == [Block.unorderedList(items: [
            Block.ListItem(
                blocks: .paragraph(content: [.text("text")]),
                .codeBlock(language: nil, code: "code\n"),
            ),
        ])].canonicalBlocks())
    }

    @Test("Nested list inside list item")
    func nestedList() {
        let blocks = [
            ParserEvent.startList(ordered: true),
            .startListItem,
            .startParagraph, .text("outer"), .endParagraph,
            .startList(ordered: false),
            .startListItem, .startParagraph, .text("inner"), .endParagraph, .endListItem,
            .endList,
            .endListItem,
            .endList,
        ].reduceToBlocks()
        #expect(blocks.canonicalBlocks() == [Block.orderedList(startIndex: 1, items: [
            Block.ListItem(
                blocks: .paragraph(content: [.text("outer")]),
                .unorderedList(items: [
                    Block.ListItem(blocks: .paragraph(content: [.text("inner")]))
                ]),
            ),
        ])].canonicalBlocks())
    }

    @Test("Blockquote with multiple children")
    func blockquoteMultipleChildren() {
        let blocks = [
            ParserEvent.startBlockQuote,
            .startParagraph, .text("first"), .endParagraph,
            .startParagraph, .text("second"), .endParagraph,
            .endBlockQuote,
        ].reduceToBlocks()
        #expect(blocks.canonicalBlocks() == [Block.makeBlockquote(
            .paragraph(content: [.text("first")]),
            .paragraph(content: [.text("second")])
        )].canonicalBlocks())
    }
}
