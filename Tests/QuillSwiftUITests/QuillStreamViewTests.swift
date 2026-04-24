@testable import QuillKit
@testable import QuillSwiftUI
import QuillSharedTestSupport
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite("QuillStreamView", .tags(.integration, .streaming))
struct QuillStreamViewTests {
    @Test("Already-rendered content is preserved after error")
    func contentRemainsAfterStreamError() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let coordinator = QuillStreamView<AsyncThrowingStream<String, Error>>.Coordinator(
            configuration: makeConfiguration()
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

    @Test("Coordinator invokes on stream finished after completion")
    func coordinatorInvokesOnStreamFinished() async throws {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let coordinator = makeCoordinator()
        let finishCapture = SignalCapture()
        coordinator.setOnStreamFinished {
            Task {
                await finishCapture.markReceived()
            }
        }
        coordinator.subscribe(to: stream, onError: nil)

        continuation.yield("Done")
        continuation.finish()

        let didFinish = await eventually {
            await finishCapture.didReceive()
        }
        #expect(didFinish)
    }

    @Test("Coordinator calls cancelStreaming and invokes onError when stream throws")
    func coordinatorHandlesStreamError() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let coordinator = QuillStreamView<AsyncThrowingStream<String, Error>>.Coordinator(
            configuration: makeConfiguration()
        )
        let errorCapture = SignalCapture()

        coordinator.subscribe(to: stream, onError: { error in
            Task {
                _ = error
                await errorCapture.markReceived()
            }
        })

        continuation.yield("Partial ")
        let partialContentRendered = await eventually {
            coordinator.quillView.currentMarkdown == "Partial "
        }
        #expect(partialContentRendered)

        continuation.finish(throwing: TestStreamError.failed)

        let recordedError = await eventually {
            await errorCapture.didReceive()
        }
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

    @Test("applyConfiguration wires link tap handler to QuillView")
    func linkTapHandlerAppliedToView() {
        let (stream, _) = AsyncStream<String>.makeStream()
        var tappedURL: URL?
        let streamView = QuillStreamView(chunks: stream)
        let view = QuillView()

        streamView.applyConfiguration(
            to: view,
            linkTapHandler: { url in tappedURL = url }
        )
        view.onLinkSelection?(URL(string: "https://example.com")!)

        #expect(tappedURL == URL(string: "https://example.com"))
    }

    @Test("stream sizing returns a finite width for an infinite proposal")
    func streamSizingFallsBackForInfiniteWidth() {
        let coordinator = makeCoordinator()
        coordinator.quillView.bounds.size.width = 260

        let result = coordinator.quillView.calculateFittedSize(for: ProposedViewSize(width: .infinity, height: nil))
        let screenWidth = coordinator.quillView.window?.screen.bounds.width ?? UIScreen.main.bounds.width
        let expectedWidth = max(coordinator.quillView.bounds.width, screenWidth)

        #expect(result?.width == expectedWidth)
        #expect(result?.width.isFinite == true)
    }
}

private actor SignalCapture {
    private var received = false

    func didReceive() -> Bool {
        received
    }

    func markReceived() {
        received = true
    }
}

private enum TestStreamError: Error {
    case failed
}

private extension QuillStreamViewTests {
    func makeCoordinator() -> QuillStreamView<AsyncStream<String>>.Coordinator {
        QuillStreamView<AsyncStream<String>>.Coordinator(
            configuration: makeConfiguration()
        )
    }

    func makeConfiguration() -> QuillConfiguration {
        QuillConfiguration(
            streaming: .init(
                mode: .bufferedModules,
                preset: .balanced
            )
        )
    }
}
