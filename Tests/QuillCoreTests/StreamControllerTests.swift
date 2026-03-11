@testable import QuillCore
import Testing

@Suite("StreamControllerTests")
struct StreamControllerTests {

    // MARK: - Basic Streaming

    @Test("Single paragraph via controller")
    func singleParagraph() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: ["Hello\n\n"])

        #expect(events == [.startParagraph, .text("Hello"), .endParagraph])
    }

    @Test("Multi-chunk produces same result as single append")
    func multiChunk() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: ["Hel", "lo\n\n"])

        #expect(events == [.startParagraph, .text("Hello"), .endParagraph])
    }

    @Test("Finish closes open paragraph")
    func finishClosesOpen() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: ["Hello\n"])

        #expect(events == [.startParagraph, .text("Hello"), .endParagraph])
    }

    @Test("Code block events through controller")
    func codeBlock() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: ["```swift\nlet x = 1\n```\n\n"])

        #expect(events == [
            .startCodeBlock(language: "swift"),
            .codeBlockText("let x = 1\n"),
            .endCodeBlock,
        ])
    }

    @Test("Empty append produces no events")
    func emptyAppend() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: [""])

        #expect(events.isEmpty)
    }

    // MARK: - Stream Lifecycle

    @Test("Stream terminates after finish")
    func streamTerminates() async {
        let controller = MarkdownStreamController()
        let stream = await controller.events()

        await controller.append("Hello\n\n")
        await controller.finish()

        var count = 0
        for await _ in stream {
            count += 1
        }
        #expect(count == 3)
    }

    @Test("Calling events() twice finishes previous stream")
    func eventsCalledTwice() async {
        let controller = MarkdownStreamController()
        let firstStream = await controller.events()
        let secondStream = await controller.events()

        var firstEvents: [ParserEvent] = []
        for await event in firstStream {
            firstEvents.append(event)
        }
        #expect(firstEvents.isEmpty)

        Task {
            await controller.append("World\n\n")
            await controller.finish()
        }

        var secondEvents: [ParserEvent] = []
        for await event in secondStream {
            secondEvents.append(event)
        }
        #expect(secondEvents == [.startParagraph, .text("World"), .endParagraph])
    }

    // MARK: - Multi-block Content

    @Test("Multiple chunks produce correct event ordering")
    func multipleChunksOrdering() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: [
            "# Title\n",
            "Body text\n",
            "\n",
        ])

        #expect(events == [
            .startHeading(level: 1), .text("Title"), .endHeading,
            .startParagraph, .text("Body text"), .endParagraph,
        ])
    }

    @Test("Full document split into arbitrary chunks matches single-string result")
    func arbitraryChunkSplitEquivalence() async {
        let document = "# Hello\n\nSome text\n\n---\n\n"

        let singleController = MarkdownStreamController()
        let singleEvents = await collectEvents(from: singleController, feeding: [document])

        let splitController = MarkdownStreamController()
        let splitEvents = await collectEvents(from: splitController, feeding: [
            "# Hel", "lo\n\nSo", "me text\n", "\n---\n\n",
        ])

        #expect(singleEvents == splitEvents)
    }

    @Test("Immediate append after events installation does not drop prefix events")
    func immediateAppendNoPrefixDrop() async {
        let controller = MarkdownStreamController()
        let stream = await controller.events()

        Task {
            await controller.append("# Title\n\n")
            await controller.finish()
        }

        var events: [ParserEvent] = []
        for await event in stream {
            events.append(event)
        }

        #expect(events.starts(with: [.startHeading(level: 1), .text("Title"), .endHeading]))
    }

    @Test("Mixed document chunks reduce into multiple block types")
    func mixedDocumentChunkedReduction() async {
        let controller = MarkdownStreamController()

        let chunks = [
            "# Str", "eaming Mixed\n\nInt", "ro paragraph.\n\n- o",
            "ne\n- two\n\n> quote l", "ine\n\n```swift\nlet x = 1\n```",
            "\n\n| Key | Value |\n| --- | --- |\n| mode | streaming |\n\n<details><summary>More context</summary>\nTail text\n</details>\n",
        ]

        let events = await collectEvents(from: controller, feeding: chunks)
        let reduced = reduce(events)

        #expect(reduced.contains { if case .heading = $0 { return true } else { return false } })
        #expect(reduced.contains { if case .unorderedList = $0 { return true } else { return false } })
        #expect(reduced.contains { if case .blockquote = $0 { return true } else { return false } })
        #expect(reduced.contains { if case .codeBlock = $0 { return true } else { return false } })
        #expect(reduced.contains { if case .table = $0 { return true } else { return false } })
        #expect(reduced.count >= 6)
    }
}

// MARK: - Static vs Streaming Parity

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
    func paragraphTransitionParity() async {
        let markdown = "First paragraph.\n\nSecond paragraph.\n\nThird paragraph.\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [4, 9, 6, 11])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Heading levels match between paths")
    func headingLevelParity() async {
        let markdown = "# H1\n\n## H2\n\n### H3\n\nBody.\n\n"

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [5, 3, 8, 6])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Ordered and unordered lists match between paths")
    func listParity() async {
        let markdown = """
        - alpha
        - beta
          - nested

        1. one
        2. two

        """

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [6, 4, 9, 7, 3])

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

        let staticBlocks = MarkdownParser.live.parse(markdown)
        let streamedBlocks = await streamAndReduce(markdown, chunkSizes: [10, 8, 14, 6, 11])

        #expect(staticBlocks == streamedBlocks)
    }

    @Test("Mixed document with all block types matches between paths")
    func mixedDocumentParity() async {
        let markdown = """
        # Title

        Intro paragraph with **bold** and *italic*.

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

        let staticBlocks = MarkdownParser.live.parse(markdown)
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
}

private extension StaticStreamingParityTests {
    func streamAndReduce(_ markdown: String, chunkSizes: [Int]) async -> [Block] {
        let chunks = chunk(markdown, sizes: chunkSizes)
        let controller = MarkdownStreamController()
        let stream = await controller.events()

        Task {
            for chunk in chunks {
                await controller.append(chunk)
            }
            await controller.finish()
        }

        var state = BlockReducer.ReducerState()
        for await event in stream {
            BlockReducer.apply(event, to: &state)
        }
        return state.blocks
    }

    func chunk(_ text: String, sizes: [Int]) -> [String] {
        let characters = Array(text)
        var index = 0
        var sizeIndex = 0
        var chunks: [String] = []

        while index < characters.count {
            let size = sizes[sizeIndex % sizes.count]
            let end = min(index + max(1, size), characters.count)
            chunks.append(String(characters[index..<end]))
            index = end
            sizeIndex += 1
        }

        return chunks
    }
}

// MARK: - Helpers

private extension StreamControllerTests {
    func collectEvents(
        from controller: MarkdownStreamController,
        feeding chunks: [String]
    ) async -> [ParserEvent] {
        let stream = await controller.events()

        Task {
            for chunk in chunks {
                await controller.append(chunk)
            }
            await controller.finish()
        }

        var collected: [ParserEvent] = []
        for await event in stream {
            collected.append(event)
        }
        
        return collected
    }

    func reduce(_ events: [ParserEvent]) -> [Block] {
        var state = BlockReducer.ReducerState()
        for event in events {
            BlockReducer.apply(event, to: &state)
        }
        return state.blocks
    }
}
