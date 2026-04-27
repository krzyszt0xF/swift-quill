@testable import QuillCore
import QuillCoreTestSupport
import QuillSharedTestSupport
@testable import QuillKit
import Testing

@MainActor
@Suite("BufferedVisualFeeder", .serialized, GloballySerialized(), .tags(.rendering, .streaming))
struct BufferedVisualFeederTests {
    @Test("makeVisualFeedChunks preserves whitespace and newline chunk boundaries")
    func makeVisualFeedChunksPreserveExpectedBoundaries() {
        let chunks = BufferedVisualFeeder.makeVisualFeedChunks(
            from: "Hi there\n\nx",
            policy: .balanced
        )

        #expect(chunks == ["Hi", " ", "there", "\n", "\n", "x"])
    }

    @Test("enqueueImmediateChunk drains queued chunks in original order")
    func enqueueImmediateChunkPreservesOrder() async {
        let controller = MarkdownStreamController()
        let eventStream = await controller.events()
        let eventsTask = Task { await collectEvents(from: eventStream) }
        let feeder = BufferedVisualFeeder(sleep: { _ in await Task.yield() })

        feeder.enqueue(
            immediateChunk: "alpha\n\n",
            policy: .balanced,
            to: controller
        )
        feeder.enqueue(
            immediateChunk: "beta\n\n",
            policy: .balanced,
            to: controller
        )

        await feeder.waitUntilDrained()
        await controller.finish()

        let events = await eventsTask.value
        let blocks = events.reduceToBlocks()
        #expect(blocks == [
            .paragraph(content: [.text("alpha")]),
            .paragraph(content: [.text("beta")]),
        ])
    }

    @Test("waitUntilDrained waits for delayed buffered chunks")
    func waitUntilDrainedWaitsForDelayedChunks() async {
        let controller = MarkdownStreamController()
        let eventStream = await controller.events()
        let eventsTask = Task { await collectEvents(from: eventStream) }
        let timeController = TestTimeController()
        let feeder = BufferedVisualFeeder(sleep: { duration in
            await timeController.sleep(for: duration)
        })

        feeder.enqueue(
            bufferedModules: ["First paragraph.\n\nSecond paragraph.\n\n"],
            policy: .balanced,
            to: controller
        )

        await feeder.waitUntilDrained()
        await controller.finish()

        let events = await eventsTask.value
        let blocks = events.reduceToBlocks()
        #expect(timeController.recordedSleeps.isEmpty == false)
        #expect(blocks == [
            .paragraph(content: [.text("First paragraph.")]),
            .paragraph(content: [.text("Second paragraph.")]),
        ])
    }

    @Test("flushRemaining appends queued text without waiting for delays")
    func flushRemainingBypassesDelayedPlayback() async {
        let controller = MarkdownStreamController()
        let eventStream = await controller.events()
        let eventsTask = Task { await collectEvents(from: eventStream) }
        let feeder = BufferedVisualFeeder(sleep: { _ in
            while Task.isCancelled == false {
                await Task.yield()
            }
        })

        feeder.enqueue(
            bufferedModules: ["First paragraph.\n\nSecond paragraph.\n\n"],
            policy: .balanced,
            to: controller
        )

        await feeder.flushRemaining(to: controller)
        await controller.finish()

        let events = await eventsTask.value
        let blocks = events.reduceToBlocks()
        #expect(blocks == [
            .paragraph(content: [.text("First paragraph.")]),
            .paragraph(content: [.text("Second paragraph.")]),
        ])
    }

    @Test(
        "flushRemaining preserves a chunk already dequeued for delayed playback",
        .disabled("flaky under full bundle load; passes in isolation; sleep request timing depends on test scheduler")
    )
    func flushRemainingPreservesDequeuedDelayedChunk() async {
        let controller = MarkdownStreamController()
        let eventStream = await controller.events()
        let eventsTask = Task { await collectEvents(from: eventStream) }
        let sleepController = ControlledSleepController()
        let feeder = BufferedVisualFeeder(sleep: { duration in
            await sleepController.sleep(for: duration)
        })

        feeder.enqueue(
            bufferedModules: ["First paragraph.\n\nSecond paragraph.\n\n"],
            policy: .balanced,
            to: controller
        )

        let delayedChunkDequeued = await eventually(timeout: .milliseconds(100)) {
            sleepController.requestCount == 1
        }
        #expect(delayedChunkDequeued)

        await feeder.flushRemaining(to: controller)
        await controller.finish()

        let events = await eventsTask.value
        let blocks = events.reduceToBlocks()
        #expect(blocks == [
            .paragraph(content: [.text("First paragraph.")]),
            .paragraph(content: [.text("Second paragraph.")]),
        ])
    }

    @Test("cancel resumes pending waitUntilDrained call")
    func cancelResumesPendingWaitUntilDrained() async {
        let controller = MarkdownStreamController()
        let feeder = BufferedVisualFeeder(sleep: { _ in
            while Task.isCancelled == false {
                await Task.yield()
            }
        })
        var didDrain = false

        feeder.enqueue(
            bufferedModules: ["First paragraph.\n\nSecond paragraph.\n\n"],
            policy: .balanced,
            to: controller
        )

        let waitTask = Task {
            await feeder.waitUntilDrained()
            didDrain = true
        }

        await Task.yield()
        #expect(didDrain == false)

        feeder.cancel()
        await waitTask.value

        #expect(didDrain)
    }
}

private extension BufferedVisualFeederTests {
    func collectEvents(
        from eventStream: AsyncStream<ParserEvent>
    ) async -> [ParserEvent] {
        var events: [ParserEvent] = []

        for await event in eventStream {
            events.append(event)
        }

        return events
    }
}
