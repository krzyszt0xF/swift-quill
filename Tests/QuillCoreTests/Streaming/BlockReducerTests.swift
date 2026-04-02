import QuillCore
import QuillCoreTestSupport
import QuillSharedTestSupport
import Testing

@Suite("BlockReducer", .tags(.streaming))
struct BlockReducerTests {
    // MARK: - Paragraphs

    @Test("Simple paragraph")
    func simpleParagraph() {
        let blocks = reduce([
            .startParagraph, .text("Hello"), .endParagraph,
        ])
        #expect(blocks == [.paragraph(content: [.text("Hello")])])
    }

    @Test("Bold text in paragraph")
    func boldText() {
        let blocks = reduce([
            .startParagraph,
            .text("a "), .startStrong, .text("bold"), .endStrong,
            .endParagraph,
        ])
        #expect(blocks == [.paragraph(content: [.text("a "), .strong([.text("bold")])])])
    }

    @Test("Multiple blocks")
    func multipleBlocks() {
        let blocks = reduce([
            .startParagraph, .text("First"), .endParagraph,
            .startParagraph, .text("Second"), .endParagraph,
        ])
        #expect(blocks.count == 2)
        #expect(blocks == [
            .paragraph(content: [.text("First")]),
            .paragraph(content: [.text("Second")]),
        ])
    }

    // MARK: - Headings

    @Test("Heading with level")
    func heading() {
        let blocks = reduce([
            .startHeading(level: 2), .text("Title"), .endHeading,
        ])
        #expect(blocks == [.heading(level: 2, content: [.text("Title")])])
    }

    // MARK: - Code Blocks

    @Test("Code block with language")
    func codeBlock() {
        let blocks = reduce([
            .startCodeBlock(language: "swift"),
            .codeBlockText("let x = 1\n"),
            .codeBlockText("let y = 2\n"),
            .endCodeBlock,
        ])
        #expect(blocks == [.codeBlock(language: "swift", code: "let x = 1\nlet y = 2\n")])
    }

    // MARK: - Lists

    @Test("Unordered list")
    func unorderedList() {
        let blocks = reduce([
            .startList(ordered: false),
            .startListItem, .startParagraph, .text("item"), .endParagraph, .endListItem,
            .endList,
        ])
        #expect(canonicalBlocks(blocks) == canonicalBlocks([.unorderedList(items: [
            makeItem(.paragraph(content: [.text("item")])),
        ])]))
    }

    @Test("Ordered list")
    func orderedList() {
        let blocks = reduce([
            .startList(ordered: true),
            .startListItem, .startParagraph, .text("first"), .endParagraph, .endListItem,
            .startListItem, .startParagraph, .text("second"), .endParagraph, .endListItem,
            .endList,
        ])
        #expect(canonicalBlocks(blocks) == canonicalBlocks([.orderedList(startIndex: 1, items: [
            makeItem(.paragraph(content: [.text("first")])),
            makeItem(.paragraph(content: [.text("second")])),
        ])]))
    }

    @Test("Task list keeps checkbox state")
    func taskList() {
        let blocks = reduce([
            .startList(ordered: false),
            .startTaskListItem(checkbox: .checked), .startParagraph, .text("done"), .endParagraph, .endListItem,
            .startTaskListItem(checkbox: .unchecked), .startParagraph, .text("pending"), .endParagraph, .endListItem,
            .endList,
        ])
        #expect(canonicalBlocks(blocks) == canonicalBlocks([.unorderedList(items: [
            makeItem(checkbox: .checked, .paragraph(content: [.text("done")])),
            makeItem(checkbox: .unchecked, .paragraph(content: [.text("pending")])),
        ])]))
    }

    // MARK: - Blockquotes

    @Test("Blockquote with paragraph")
    func blockquote() {
        let blocks = reduce([
            .startBlockQuote,
            .startParagraph, .text("quoted"), .endParagraph,
            .endBlockQuote,
        ])
        #expect(canonicalBlocks(blocks) == canonicalBlocks([makeBlockquote(.paragraph(content: [.text("quoted")]))]))
    }

    // MARK: - Thematic Break

    @Test("Thematic break")
    func thematicBreak() {
        let blocks = reduce([.thematicBreak])
        #expect(blocks == [.thematicBreak])
    }

    // MARK: - Tables

    @Test("Table with header and data row")
    func table() {
        let blocks = reduce([
            .startTable,
            .tableAlignments([nil, nil]),
            .tableRow(["A", "B"]),
            .tableRow(["1", "2"]),
            .endTable,
        ])
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
        let blocks = reduce([
            .startTable,
            .tableAlignments([.left, .center, .right]),
            .tableRow(["A", "B", "C"]),
            .tableRow(["1", "2", "3"]),
            .endTable,
        ])

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
        let blocks = reduce([
            .startTable,
            .tableAlignments([nil, nil, nil]),
            .tableRow(["**bold**", "*italic*", "`code`"]),
            .endTable,
        ])

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
        let blocks = reduce([
            .startParagraph,
            .startEmphasis, .startStrong, .text("both"), .endStrong, .endEmphasis,
            .endParagraph,
        ])
        #expect(blocks == [.paragraph(content: [
            .emphasis([.strong([.text("both")])]),
        ])])
    }

    @Test("Inline code")
    func inlineCode() {
        let blocks = reduce([
            .startParagraph,
            .startInlineCode, .text("code"), .endInlineCode,
            .endParagraph,
        ])
        #expect(blocks == [.paragraph(content: [.code("code")])])
    }

    @Test("Link")
    func link() {
        let blocks = reduce([
            .startParagraph,
            .startLink(destination: "url"), .text("click"), .endLink,
            .endParagraph,
        ])
        #expect(blocks == [.paragraph(content: [
            .link(destination: "url", children: [.text("click")]),
        ])])
    }

    @Test("Strikethrough")
    func strikethrough() {
        let blocks = reduce([
            .startParagraph,
            .startStrikethrough, .text("deleted"), .endStrikethrough,
            .endParagraph,
        ])
        #expect(blocks == [.paragraph(content: [.strikethrough([.text("deleted")])])])
    }

    @Test("Image in paragraph")
    func image() {
        let blocks = reduce([
            .startParagraph,
            .image(source: "url", title: "t", alt: "a"),
            .endParagraph,
        ])
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
        #expect(canonicalBlocks(state.blocks.map(\.block)) == canonicalBlocks([
            .unorderedList(items: [
                makeItem(.paragraph(content: [.text("item")]))
            ])
        ]))
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
        #expect(canonicalBlocks(state.blocks.map(\.block)) == canonicalBlocks([
            .unorderedList(items: [
                makeItem(
                    .paragraph(content: [.text("item")]),
                    .table(
                        columnAlignments: [nil, nil],
                        header: Block.TableRow(cells: []),
                        rows: []
                    )
                )
            ])
        ]))
    }

    // MARK: - Determinism

    @Test("Deterministic: same events produce same blocks")
    func determinism() {
        let events: [ParserEvent] = [
            .startParagraph, .text("Hello"), .endParagraph,
            .startHeading(level: 2), .text("Title"), .endHeading,
            .thematicBreak,
        ]
        let blocks1 = reduce(events)
        let blocks2 = reduce(events)
        #expect(blocks1 == blocks2)
    }

    // MARK: - Nested Blocks

    @Test("List item with multiple blocks")
    func listItemWithMultipleBlocks() {
        let blocks = reduce([
            .startList(ordered: false),
            .startListItem,
            .startParagraph, .text("text"), .endParagraph,
            .startCodeBlock(language: nil), .codeBlockText("code\n"), .endCodeBlock,
            .endListItem,
            .endList,
        ])
        #expect(canonicalBlocks(blocks) == canonicalBlocks([.unorderedList(items: [
            makeItem(
                .paragraph(content: [.text("text")]),
                .codeBlock(language: nil, code: "code\n"),
            ),
        ])]))
    }

    @Test("Nested list inside list item")
    func nestedList() {
        let blocks = reduce([
            .startList(ordered: true),
            .startListItem,
            .startParagraph, .text("outer"), .endParagraph,
            .startList(ordered: false),
            .startListItem, .startParagraph, .text("inner"), .endParagraph, .endListItem,
            .endList,
            .endListItem,
            .endList,
        ])
        #expect(canonicalBlocks(blocks) == canonicalBlocks([.orderedList(startIndex: 1, items: [
            makeItem(
                .paragraph(content: [.text("outer")]),
                .unorderedList(items: [
                    makeItem(.paragraph(content: [.text("inner")]))
                ]),
            ),
        ])]))
    }

    @Test("Blockquote with multiple children")
    func blockquoteMultipleChildren() {
        let blocks = reduce([
            .startBlockQuote,
            .startParagraph, .text("first"), .endParagraph,
            .startParagraph, .text("second"), .endParagraph,
            .endBlockQuote,
        ])
        #expect(canonicalBlocks(blocks) == canonicalBlocks([makeBlockquote(
            .paragraph(content: [.text("first")]),
            .paragraph(content: [.text("second")])
        )]))
    }
}
