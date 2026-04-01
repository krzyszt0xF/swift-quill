@testable import QuillCore
import QuillCoreTestSupport
import Testing

@Suite("StreamController")
struct StreamControllerTests {

    // MARK: - Basic Streaming

    @Test("Single paragraph via controller")
    func singleParagraph() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: ["Hello\n\n"])

        #expect(events == [.startParagraph, .text("Hello"), .endParagraph])
    }

    @Test("Multi-chunk produces same result as single append")
    func multiChunkMatchesSingleAppend() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: ["Hel", "lo\n\n"])

        #expect(events == [.startParagraph, .text("Hello"), .endParagraph])
    }

    @Test("Finish closes open paragraph")
    func finishClosesOpenParagraph() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: ["Hello\n"])

        #expect(events == [.startParagraph, .text("Hello"), .endParagraph])
    }

    @Test("Code block events through controller")
    func codeBlockProducesExpectedEvents() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: ["```swift\nlet x = 1\n```\n\n"])

        #expect(events == [
            .startCodeBlock(language: "swift"),
            .codeBlockText("let x = 1\n"),
            .endCodeBlock,
        ])
    }

    @Test("Empty append produces no events")
    func emptyAppendProducesNoEvents() async {
        let controller = MarkdownStreamController()
        let events = await collectEvents(from: controller, feeding: [""])

        #expect(events.isEmpty)
    }

    // MARK: - Stream Lifecycle

    @Test("Stream terminates after finish")
    func streamTerminatesAfterFinish() async {
        let controller = MarkdownStreamController()
        let eventStream = await controller.events()

        await controller.append("Hello\n\n")
        await controller.finish()

        var eventCount = 0
        for await _ in eventStream {
            eventCount += 1
        }
        #expect(eventCount == 3)
    }

    @Test("Calling events() twice finishes previous stream")
    func secondEventsCallFinishesPreviousStream() async {
        let controller = MarkdownStreamController()
        let firstEventStream = await controller.events()
        let secondEventStream = await controller.events()

        var firstStreamEvents: [ParserEvent] = []
        for await event in firstEventStream {
            firstStreamEvents.append(event)
        }
        #expect(firstStreamEvents.isEmpty)

        Task {
            await controller.append("World\n\n")
            await controller.finish()
        }

        var secondStreamEvents: [ParserEvent] = []
        for await event in secondEventStream {
            secondStreamEvents.append(event)
        }
        #expect(secondStreamEvents == [.startParagraph, .text("World"), .endParagraph])
    }

    // MARK: - Multi-block Content

    @Test("Multiple chunks produce correct event ordering")
    func multipleChunksPreserveEventOrdering() async {
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
    func arbitraryChunkSplitsMatchSingleString() async {
        let document = "# Hello\n\nSome text\n\n---\n\n"

        let singleController = MarkdownStreamController()
        let singleEvents = await collectEvents(from: singleController, feeding: [document])

        let splitController = MarkdownStreamController()
        let splitEvents = await collectEvents(from: splitController, feeding: [
            "# Hel", "lo\n\nSo", "me text\n", "\n---\n\n",
        ])

        #expect(singleEvents == splitEvents)
    }

    @Test("Split heading emits incremental events before newline")
    func splitHeadingEmitsIncrementalEvents() async {
        let controller = MarkdownStreamController()
        let eventStream = await controller.events()

        Task {
            await controller.append("# Hel")
            await controller.append("lo\n")
            await controller.finish()
        }

        var events: [ParserEvent] = []
        for await event in eventStream {
            events.append(event)
        }

        #expect(events == [
            .startHeading(level: 1),
            .text("Hel"),
            .text("lo"),
            .endHeading,
        ])
    }

    @Test("Paragraph to split heading emits paragraph close before heading preview")
    func paragraphToSplitHeadingEmitsIncrementalHeadingEvents() async {
        let controller = MarkdownStreamController()
        let eventStream = await controller.events()

        Task {
            await controller.append("Intro paragraph\n## Tit")
            await controller.append("le\n")
            await controller.finish()
        }

        var events: [ParserEvent] = []
        for await event in eventStream {
            events.append(event)
        }

        #expect(events == [
            .startParagraph,
            .text("Intro paragraph"),
            .endParagraph,
            .startHeading(level: 2),
            .text("Tit"),
            .text("le"),
            .endHeading,
        ])
    }

    @Test("Immediate append after events installation does not drop prefix events")
    func immediateAppendKeepsPrefixEvents() async {
        let controller = MarkdownStreamController()
        let eventStream = await controller.events()

        Task {
            await controller.append("# Title\n\n")
            await controller.finish()
        }

        var events: [ParserEvent] = []
        for await event in eventStream {
            events.append(event)
        }

        #expect(events.starts(with: [.startHeading(level: 1), .text("Title"), .endHeading]))
    }

    @Test("Append before events installation keeps pending events")
    func appendBeforeEventsKeepsPendingEvents() async {
        let controller = MarkdownStreamController()

        await controller.append("Hello\n\n")
        await controller.finish()

        let eventStream = await controller.events()

        var events: [ParserEvent] = []
        for await event in eventStream {
            events.append(event)
        }

        #expect(events == [.startParagraph, .text("Hello"), .endParagraph])
    }

    @Test("Mixed document chunks reduce into multiple block types")
    func mixedDocumentChunksReduceToExpectedBlockTypes() async {
        let controller = MarkdownStreamController()

        let chunks = [
            "# Str", "eaming Mixed\n\nInt", "ro paragraph.\n\n- o",
            "ne\n- two\n\n> quote l", "ine\n\n```swift\nlet x = 1\n```",
            "\n\n| Key | Value |\n| --- | --- |\n| mode | streaming |\n\n<details><summary>More context</summary>\nTail text\n</details>\n",
        ]

        let events = await collectEvents(from: controller, feeding: chunks)
        let reducedBlocks = reduce(events)

        #expect(reducedBlocks.contains { if case .heading = $0 { return true } else { return false } })
        #expect(reducedBlocks.contains { if case .unorderedList = $0 { return true } else { return false } })
        #expect(reducedBlocks.contains { if case .blockquote = $0 { return true } else { return false } })
        #expect(reducedBlocks.contains { if case .codeBlock = $0 { return true } else { return false } })
        #expect(reducedBlocks.contains { if case .table = $0 { return true } else { return false } })
        #expect(reducedBlocks.count >= 6)
    }
}
