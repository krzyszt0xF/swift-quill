@testable import QuillCore
import QuillCoreTestSupport
import Testing

@Suite("Static vs Streaming Parity")
struct StaticStreamingParityTests {
    @Test("Simple document produces identical blocks through static and streaming paths")
    func simpleDocumentParity() async {
        let markdown = "# Hello\n\nSome text.\n\n---\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [3, 7, 5])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Paragraph transitions match between paths")
    func paragraphTransitionsParity() async {
        let markdown = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [4, 9, 6, 11])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Heading levels match between paths")
    func headingLevelsParity() async {
        let markdown = "# H1\n\n## H2\n\n### H3\n\nBody.\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [5, 3, 8, 6])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Flat ordered and unordered lists match between paths")
    func flatOrderedAndUnorderedListsParity() async {
        let markdown = """
        - alpha
        - beta

        1. one
        2. two

        """

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [6, 4, 9, 7, 3])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Task list matches between paths")
    func taskListParity() async {
        let markdown = """
        - [x] done
        - [ ] pending

        """

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [3, 5, 4, 2, 6])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Nested unordered list matches between paths")
    func nestedUnorderedListParity() async {
        let markdown = """
        - outer
          - inner
        - after

        """

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [2, 4, 3, 5, 2])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Nested ordered list matches between paths")
    func nestedOrderedListParity() async {
        let markdown = """
        1. first
           1. nested
           2. verification
        2. second

        """

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [3, 4, 5, 2, 6])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Nested task list matches between paths")
    func nestedTaskListParity() async {
        let markdown = """
        - [x] heading
          - [x] nested requirement
          - [ ] nested follow-up
        - [ ] full verification

        """

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [3, 4, 6, 2, 5])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Code fence with language matches between paths")
    func codeFenceParity() async {
        let markdown = "```swift\nlet x = 1\nlet y = 2\n```\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [8, 5, 12, 7])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Table matches between paths")
    func tableParity() async {
        let markdown = """
        | Key | Value |
        | --- | --- |
        | mode | streaming |
        | state | active |

        """

        let staticBlocks = streamingComparable(MarkdownParser.live.parse(markdown))
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [10, 8, 14, 6, 11])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Mixed document with supported streaming block types matches between paths")
    func supportedMixedDocumentParity() async {
        let markdown = """
        # Title

        Intro paragraph.

        - bullet one
        - bullet two

        1. ordered one
        2. ordered two

        > A blockquote.

        ```swift
        let x = 1
        ```

        | A | B |
        | - | - |
        | 1 | 2 |

        ---

        Closing paragraph.

        """

        let staticBlocks = streamingComparable(MarkdownParser.live.parse(markdown))
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [3, 7, 5, 9, 4, 11, 6, 8])

        #expect(staticBlocks == streamedBlocks)
        #expect(staticBlocks.count == streamedBlocks.count)
    }

    @Test("Single-character chunk splits produce parity")
    func singleCharacterChunkParity() async {
        let markdown = "# Hi\n\nWorld.\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [1])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Formatted paragraph matches between static and streaming paths")
    func formattedParagraphParity() async {
        let markdown = "**bold** and *italic* with `code`\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [4, 5, 3, 7])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Link paragraph matches between static and streaming paths")
    func linkParagraphParity() async {
        let markdown = "Hello [link](http://url) world\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [3, 6, 4, 5])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Nested formatting matches between static and streaming paths")
    func nestedFormattingParity() async {
        let markdown = "**bold *and italic***\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [2, 4, 3, 5])

        #expect(staticBlocks == streamedBlocks)
    }
}

private extension StaticStreamingParityTests {
    func streamingComparable(_ blocks: [Block]) -> [Block] {
        blocks.map(streamingComparable)
    }

    func streamingComparable(_ block: Block) -> Block {
        switch block {
        case let .blockquote(children):
            return .blockquote(children: children.map(streamingComparable))
        case .codeBlock, .heading, .htmlBlock, .paragraph, .thematicBreak:
            return block
        case let .orderedList(startIndex, items):
            let normalizedItems = items.map { item in
                Block.ListItem(
                    checkbox: item.checkbox,
                    children: item.children.map(streamingComparable)
                )
            }
            return .orderedList(startIndex: startIndex, items: normalizedItems)
        case let .table(_, header, rows):
            return .table(columnAlignments: [], header: header, rows: rows)
        case let .unorderedList(items):
            let normalizedItems = items.map { item in
                Block.ListItem(
                    checkbox: item.checkbox,
                    children: item.children.map(streamingComparable)
                )
            }
            return .unorderedList(items: normalizedItems)
        }
    }
}
