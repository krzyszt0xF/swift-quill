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
            .codeBlockText("let x = 1"),
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
}
