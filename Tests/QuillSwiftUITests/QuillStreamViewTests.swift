@testable import QuillKit
@testable import QuillSwiftUI
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillStreamView")
struct QuillStreamViewTests {
    @Test("Already-rendered content is preserved after error")
    func contentRemainsAfterStreamError() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let coordinator = QuillStreamView<AsyncThrowingStream<String, Error>>.Coordinator(
            preset: .balanced,
            mode: .bufferedModules
        )

        coordinator.subscribe(to: stream, onError: { _ in })

        continuation.yield("Kept ")
        let partialContentRendered = await eventually {
            coordinator.quillView.currentMarkdown == "Kept "
        }
        #expect(partialContentRendered)

        continuation.finish(throwing: TestStreamError.failed)
        let preservedContent = await eventually {
            coordinator.quillView.currentMarkdown == "Kept "
        }
        #expect(preservedContent)
    }

    @Test("cancel() cancels subscription task and calls cancelStreaming")
    func cancelStopsSubscription() async throws {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let coordinator = makeCoordinator()
        coordinator.subscribe(to: stream, onError: nil)

        continuation.yield("Before")
        let initialContentRendered = await eventually {
            coordinator.quillView.currentMarkdown == "Before"
        }
        #expect(initialContentRendered)

        let markdownBeforeCancel = coordinator.quillView.currentMarkdown
        coordinator.cancel()

        continuation.yield("After")
        await wait(for: .milliseconds(50))

        #expect(markdownBeforeCancel == "Before")
        #expect(coordinator.quillView.currentMarkdown == "Before")
    }

    @Test("Coordinator subscribes to AsyncSequence and calls append per chunk")
    func coordinatorAppendsChunks() async throws {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let coordinator = makeCoordinator()
        coordinator.subscribe(to: stream, onError: nil)

        continuation.yield("Hello ")
        continuation.yield("world")
        continuation.finish()

        let renderedCombinedMarkdown = await eventually {
            coordinator.quillView.currentMarkdown == "Hello world"
        }
        #expect(renderedCombinedMarkdown)
    }

    @Test("Coordinator calls finish after stream completes normally")
    func coordinatorFinishesAfterCompletion() async throws {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let coordinator = makeCoordinator()
        coordinator.subscribe(to: stream, onError: nil)

        continuation.yield("Done")
        continuation.finish()

        let renderedMarkdown = await eventually {
            coordinator.quillView.currentMarkdown == "Done"
        }
        #expect(renderedMarkdown)
    }

    @Test("Coordinator calls cancelStreaming and invokes onError when stream throws")
    func coordinatorHandlesStreamError() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let coordinator = QuillStreamView<AsyncThrowingStream<String, Error>>.Coordinator(
            preset: .balanced,
            mode: .bufferedModules
        )
        let errorCapture = ErrorCapture()

        coordinator.subscribe(to: stream, onError: { error in
            Task {
                await errorCapture.store(error)
            }
        })

        continuation.yield("Partial ")
        let partialContentRendered = await eventually {
            coordinator.quillView.currentMarkdown == "Partial "
        }
        #expect(partialContentRendered)

        continuation.finish(throwing: TestStreamError.failed)

        let recordedError = await errorCapture.waitForValue(timeout: .milliseconds(800))
        #expect(recordedError)
        #expect(coordinator.quillView.currentMarkdown == "Partial ")
    }

    @Test("Generation counter prevents stale chunks from interleaving")
    func generationCounterPreventsStaleChunksFromInterleaving() async throws {
        let (firstStream, firstContinuation) = AsyncStream<String>.makeStream()
        let (secondStream, secondContinuation) = AsyncStream<String>.makeStream()
        let coordinator = makeCoordinator()

        coordinator.subscribe(to: firstStream, onError: nil)
        firstContinuation.yield("First ")
        let initialContentRendered = await eventually {
            coordinator.quillView.currentMarkdown == "First "
        }
        #expect(initialContentRendered)

        coordinator.subscribe(to: secondStream, onError: nil)

        firstContinuation.yield("stale")
        secondContinuation.yield("Second")

        let replacedContentRendered = await eventually {
            coordinator.quillView.currentMarkdown == "Second"
        }
        #expect(replacedContentRendered)
    }
}

private actor ErrorCapture {
    private var error: Error?

    func hasValue() -> Bool {
        error != nil
    }

    func waitForValue(timeout: Duration) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if hasValue() {
                return true
            }

            try? await Task.sleep(for: .milliseconds(10))
        }

        return hasValue()
    }

    func store(_ error: Error) {
        self.error = error
    }
}

private enum TestStreamError: Error {
    case failed
}

private extension QuillStreamViewTests {
    func makeCoordinator() -> QuillStreamView<AsyncStream<String>>.Coordinator {
        QuillStreamView<AsyncStream<String>>.Coordinator(
            preset: .balanced,
            mode: .bufferedModules
        )
    }

}
