import QuillCore
import QuillCoreTestSupport
import Testing

@Suite("BlockReducer")
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
        #expect(blocks == [.unorderedList(items: [
            Block.ListItem(children: [.paragraph(content: [.text("item")])]),
        ])])
    }

    @Test("Ordered list")
    func orderedList() {
        let blocks = reduce([
            .startList(ordered: true),
            .startListItem, .startParagraph, .text("first"), .endParagraph, .endListItem,
            .startListItem, .startParagraph, .text("second"), .endParagraph, .endListItem,
            .endList,
        ])
        #expect(blocks == [.orderedList(startIndex: 1, items: [
            Block.ListItem(children: [.paragraph(content: [.text("first")])]),
            Block.ListItem(children: [.paragraph(content: [.text("second")])]),
        ])])
    }

    @Test("Task list keeps checkbox state")
    func taskList() {
        let blocks = reduce([
            .startList(ordered: false),
            .startTaskListItem(checkbox: .checked), .startParagraph, .text("done"), .endParagraph, .endListItem,
            .startTaskListItem(checkbox: .unchecked), .startParagraph, .text("pending"), .endParagraph, .endListItem,
            .endList,
        ])
        #expect(blocks == [.unorderedList(items: [
            Block.ListItem(checkbox: .checked, children: [.paragraph(content: [.text("done")])]),
            Block.ListItem(checkbox: .unchecked, children: [.paragraph(content: [.text("pending")])]),
        ])])
    }

    // MARK: - Blockquotes

    @Test("Blockquote with paragraph")
    func blockquote() {
        let blocks = reduce([
            .startBlockQuote,
            .startParagraph, .text("quoted"), .endParagraph,
            .endBlockQuote,
        ])
        #expect(blocks == [.blockquote(children: [.paragraph(content: [.text("quoted")])])])
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
            .tableRow(["A", "B"]),
            .tableRow(["1", "2"]),
            .endTable,
        ])
        #expect(blocks == [.table(
            columnAlignments: [],
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
        #expect(blocks == [.unorderedList(items: [
            Block.ListItem(children: [
                .paragraph(content: [.text("text")]),
                .codeBlock(language: nil, code: "code\n"),
            ]),
        ])])
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
        #expect(blocks == [.orderedList(startIndex: 1, items: [
            Block.ListItem(children: [
                .paragraph(content: [.text("outer")]),
                .unorderedList(items: [
                    Block.ListItem(children: [.paragraph(content: [.text("inner")])]),
                ]),
            ]),
        ])])
    }

    @Test("Blockquote with multiple children")
    func blockquoteMultipleChildren() {
        let blocks = reduce([
            .startBlockQuote,
            .startParagraph, .text("first"), .endParagraph,
            .startParagraph, .text("second"), .endParagraph,
            .endBlockQuote,
        ])
        #expect(blocks == [.blockquote(children: [
            .paragraph(content: [.text("first")]),
            .paragraph(content: [.text("second")]),
        ])])
    }

    // MARK: - Tail Preview Inline Parsing

    @Test("Tail preview parses bold in paragraph")
    func tailPreviewBoldParagraph() {
        let tail = tailPreview(after: [
            .startParagraph, .text("Hello **world**"),
        ])
        #expect(tail == .paragraph(content: [
            .text("Hello "),
            .strong([.text("world")]),
        ]))
    }

    @Test("Tail preview parses bold in heading")
    func tailPreviewBoldHeading() {
        let tail = tailPreview(after: [
            .startHeading(level: 2), .text("**bold heading**"),
        ])
        #expect(tail == .heading(level: 2, content: [
            .strong([.text("bold heading")]),
        ]))
    }

    @Test("Tail preview parses emphasis in list item")
    func tailPreviewEmphasisInList() {
        let tail = tailPreview(after: [
            .startList(ordered: false),
            .startListItem,
            .startParagraph, .text("*item*"),
        ])
        guard case let .unorderedList(items) = tail,
              let firstItem = items.first,
              let firstBlock = firstItem.children.first,
              case let .paragraph(content) = firstBlock
        else {
            Issue.record("Expected unordered list with emphasis item")
            return
        }
        #expect(content == [.emphasis([.text("item")])])
    }

    @Test("Tail preview parses code in blockquote")
    func tailPreviewCodeInBlockquote() {
        let tail = tailPreview(after: [
            .startBlockQuote,
            .startParagraph, .text("`code` text"),
        ])
        guard case let .blockquote(children) = tail,
              let firstBlock = children.first,
              case let .paragraph(content) = firstBlock
        else {
            Issue.record("Expected blockquote with code inline")
            return
        }
        #expect(content == [.code("code"), .text(" text")])
    }

    @Test("Tail preview joins multi-line text with inline parsing")
    func tailPreviewMultiLine() {
        let tail = tailPreview(after: [
            .startParagraph, .text("Hello **bold"), .text(" continues**"),
        ])
        #expect(tail == .paragraph(content: [
            .text("Hello "),
            .strong([.text("bold continues")]),
        ]))
    }

    @Test("Tail preview does not invent separators between text fragments")
    func tailPreviewDoesNotInventSeparators() {
        let tail = tailPreview(after: [
            .startParagraph, .text("Hello"), .text("world"),
        ])
        #expect(tail == .paragraph(content: [.text("Helloworld")]))
    }

    @Test("Tail preview strips incomplete bold markers")
    func tailPreviewIncompleteBold() {
        let tail = tailPreview(after: [
            .startParagraph, .text("Hello **bold"),
        ])
        #expect(tail == .paragraph(content: [.text("Hello bold")]))
    }

    @Test("Tail preview renders speculative code")
    func tailPreviewSpeculativeCode() {
        let tail = tailPreview(after: [
            .startParagraph, .text("Use `method"),
        ])
        #expect(tail == .paragraph(content: [
            .text("Use "),
            .code("method"),
        ]))
    }
}
