@testable import QuillKit
@testable import QuillSwiftUI
import Testing
import UIKit

@MainActor
@Suite("QuillStreamView")
struct QuillStreamViewTests {
    @Test("Coordinator subscribes to AsyncSequence and calls append per chunk")
    func coordinatorAppendsChunks() async throws {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let coordinator = makeCoordinator()
        coordinator.subscribe(to: stream, onError: nil)

        continuation.yield("Hello ")
        continuation.yield("world")
        continuation.finish()

        try await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.quillView.currentMarkdown == "Hello world")
    }

    @Test("Coordinator calls finish after stream completes normally")
    func coordinatorFinishesOnCompletion() async throws {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let coordinator = makeCoordinator()
        coordinator.subscribe(to: stream, onError: nil)

        continuation.yield("Done")
        continuation.finish()

        try await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.quillView.currentMarkdown == "Done")
    }

    @Test("Coordinator calls cancelStreaming and invokes onError when stream throws")
    func coordinatorHandlesStreamError() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let coordinator = QuillStreamView<AsyncThrowingStream<String, Error>>.Coordinator(
            preset: .balanced,
            mode: .bufferedModules
        )

        nonisolated(unsafe) var receivedError: Error?
        coordinator.subscribe(to: stream, onError: { error in
            receivedError = error
        })

        continuation.yield("Partial ")
        try await Task.sleep(for: .milliseconds(20))

        continuation.finish(throwing: TestStreamError.failed)
        try await Task.sleep(for: .milliseconds(50))

        #expect(receivedError != nil)
        #expect(coordinator.quillView.currentMarkdown == "Partial ")
    }

    @Test("cancel() cancels subscription task and calls cancelStreaming")
    func cancelStopsSubscription() async throws {
        let (stream, continuation) = AsyncStream<String>.makeStream()
        let coordinator = makeCoordinator()
        coordinator.subscribe(to: stream, onError: nil)

        continuation.yield("Before")
        try await Task.sleep(for: .milliseconds(20))

        let markdownBeforeCancel = coordinator.quillView.currentMarkdown
        coordinator.cancel()

        continuation.yield("After")
        try await Task.sleep(for: .milliseconds(50))

        #expect(markdownBeforeCancel == "Before")
        #expect(coordinator.quillView.currentMarkdown == "Before")
    }

    @Test("Generation counter prevents stale chunks from interleaving")
    func generationCounterPreventsStaleChunks() async throws {
        let (stream1, continuation1) = AsyncStream<String>.makeStream()
        let (stream2, continuation2) = AsyncStream<String>.makeStream()
        let coordinator = makeCoordinator()

        coordinator.subscribe(to: stream1, onError: nil)
        continuation1.yield("First ")
        try await Task.sleep(for: .milliseconds(20))

        coordinator.subscribe(to: stream2, onError: nil)

        continuation1.yield("stale")
        continuation2.yield("Second")
        try await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.quillView.currentMarkdown == "Second")
    }

    @Test("Already-rendered content is preserved after error")
    func contentPreservedAfterError() async throws {
        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream()
        let coordinator = QuillStreamView<AsyncThrowingStream<String, Error>>.Coordinator(
            preset: .balanced,
            mode: .bufferedModules
        )

        coordinator.subscribe(to: stream, onError: { _ in })

        continuation.yield("Kept ")
        try await Task.sleep(for: .milliseconds(20))

        continuation.finish(throwing: TestStreamError.failed)
        try await Task.sleep(for: .milliseconds(50))

        #expect(coordinator.quillView.currentMarkdown == "Kept ")
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
