@testable import QuillKit
import QuillCore
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("HighlightCoordinator", .tags(.rendering))
struct HighlightCoordinatorTests {
    @Test("reapplying highlighter keeps stored results visible")
    func reapplyingHighlighterKeepsStoredResultsVisible() async {
        let coordinator = makeCoordinator()
        let highlighter = CountingHighlighter(result: makeHighlightedCode())
        let blockID = BlockIdentity(rawValue: 1)

        coordinator.set(highlighter: highlighter)
        coordinator.scheduleHighlight(blockID: blockID, code: "let x = 1", language: "swift")

        let highlighted = await eventually {
            coordinator.highlightedResult(for: blockID) != nil
        }

        #expect(highlighted)
        #expect(highlighter.callCount == 1)

        coordinator.set(highlighter: highlighter)

        #expect(coordinator.highlightedResult(for: blockID) != nil)
        #expect(highlighter.callCount == 1)
    }

    @Test("disabling and reenabling highlighter reuses cached result")
    func disablingAndReenablingHighlighterReusesCachedResult() async {
        let coordinator = makeCoordinator()
        let highlighter = CountingHighlighter(result: makeHighlightedCode())
        let blockID = BlockIdentity(rawValue: 2)

        coordinator.set(highlighter: highlighter)
        coordinator.scheduleHighlight(blockID: blockID, code: "let x = 1", language: "swift")

        let highlighted = await eventually {
            coordinator.highlightedResult(for: blockID) != nil
        }

        #expect(highlighted)
        #expect(highlighter.callCount == 1)

        coordinator.set(highlighter: nil)
        #expect(coordinator.highlightedResult(for: blockID) == nil)

        coordinator.set(highlighter: highlighter)
        #expect(coordinator.highlightedResult(for: blockID) != nil)
        #expect(highlighter.callCount == 1)
    }

    @Test("cancelAll keeps finalized result and sink registration")
    func cancelAllKeepsFinalizedResult() async {
        let coordinator = makeCoordinator()
        let highlighter = CountingHighlighter(result: makeHighlightedCode())
        let blockID = BlockIdentity(rawValue: 20)
        let sink = CapturingSink()

        coordinator.set(highlighter: highlighter)
        coordinator.registerSink(sink, for: blockID)
        coordinator.scheduleHighlight(blockID: blockID, code: "let x = 1", language: "swift")

        let applied = await eventually { sink.appliedCount >= 1 }
        #expect(applied)
        #expect(coordinator.highlightedResult(for: blockID) != nil)

        coordinator.cancelAll()

        #expect(coordinator.highlightedResult(for: blockID) != nil)

        let secondBlockID = BlockIdentity(rawValue: 21)
        let secondSink = CapturingSink()
        coordinator.registerSink(secondSink, for: secondBlockID)
        coordinator.scheduleHighlight(blockID: secondBlockID, code: "let x = 1", language: "swift")

        let reused = await eventually { secondSink.appliedCount >= 1 }
        #expect(reused)
        #expect(highlighter.callCount == 1)
    }

    @Test("reset clears finalized result and content cache")
    func resetClearsFinalizedResult() async {
        let coordinator = makeCoordinator()
        let highlighter = CountingHighlighter(result: makeHighlightedCode())
        let blockID = BlockIdentity(rawValue: 30)

        coordinator.set(highlighter: highlighter)
        coordinator.scheduleHighlight(blockID: blockID, code: "let x = 1", language: "swift")

        let highlighted = await eventually { coordinator.highlightedResult(for: blockID) != nil }
        #expect(highlighted)

        coordinator.reset()

        #expect(coordinator.highlightedResult(for: blockID) == nil)

        coordinator.set(highlighter: highlighter)
        coordinator.scheduleHighlight(blockID: blockID, code: "let x = 1", language: "swift")

        let recomputed = await eventually { highlighter.callCount == 2 }
        #expect(recomputed)
    }

    @Test("cancelAll drops in-flight request so late result is discarded")
    func cancelAllCancelsInFlightRequest() async {
        let coordinator = makeCoordinator()
        let highlighter = GatedHighlighter(result: makeHighlightedCode())
        let blockID = BlockIdentity(rawValue: 40)
        let sink = CapturingSink()

        coordinator.set(highlighter: highlighter)
        coordinator.registerSink(sink, for: blockID)
        coordinator.scheduleHighlight(blockID: blockID, code: "let x = 1", language: "swift")

        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                highlighter.startedSignal.wait()
                continuation.resume()
            }
        }

        coordinator.cancelAll()
        highlighter.allowFinishSignal.signal()

        try? await Task.sleep(nanoseconds: 150_000_000)

        #expect(coordinator.highlightedResult(for: blockID) == nil)
        #expect(sink.appliedCount == 0)
    }

    @Test("failed highlight is not cached and next schedule retries")
    func failedHighlightIsNotCached() async {
        let coordinator = makeCoordinator()
        let highlighter = CountingHighlighter(result: nil)
        let blockID = BlockIdentity(rawValue: 3)

        coordinator.set(highlighter: highlighter)
        coordinator.scheduleHighlight(blockID: blockID, code: "let x = 1", language: "swift")

        let firstAttemptFinished = await eventually {
            highlighter.callCount == 1
        }

        #expect(firstAttemptFinished)
        #expect(coordinator.highlightedResult(for: blockID) == nil)

        highlighter.result = makeHighlightedCode()
        coordinator.scheduleHighlight(blockID: blockID, code: "let x = 1", language: "swift")

        let retried = await eventually {
            coordinator.highlightedResult(for: blockID) != nil
        }

        #expect(retried)
        #expect(highlighter.callCount == 2)
    }
}

private extension HighlightCoordinatorTests {
    func makeCoordinator() -> HighlightCoordinator {
        HighlightCoordinator(
            cacheLimit: 10,
            highlightQueue: DispatchQueue(
                label: "HighlightCoordinatorTests",
                qos: .userInitiated
            )
        )
    }

    func makeHighlightedCode() -> NSAttributedString {
        let highlighted = NSMutableAttributedString(string: "let x = 1")
        highlighted.addAttribute(
            .foregroundColor,
            value: UIColor.systemRed,
            range: NSRange(location: 0, length: 3)
        )
        return highlighted
    }

    final class CountingHighlighter: SyntaxHighlighting, @unchecked Sendable {
        private let lock = NSLock()
        private var callCountValue = 0
        private var storedResult: NSAttributedString?

        init(result: NSAttributedString?) {
            self.storedResult = result
        }

        var callCount: Int {
            lock.withLock {
                callCountValue
            }
        }

        var result: NSAttributedString? {
            get {
                lock.withLock {
                    storedResult
                }
            }
            set {
                lock.withLock {
                    storedResult = newValue
                }
            }
        }

        func highlight(code: String, language: String) -> NSAttributedString? {
            lock.withLock {
                callCountValue += 1
                guard let storedResult else { return nil }
                return NSAttributedString(attributedString: storedResult)
            }
        }
    }

    final class GatedHighlighter: SyntaxHighlighting, @unchecked Sendable {
        let startedSignal = DispatchSemaphore(value: 0)
        let allowFinishSignal = DispatchSemaphore(value: 0)
        private let storedResult: NSAttributedString?

        init(result: NSAttributedString?) {
            self.storedResult = result
        }

        func highlight(code: String, language: String) -> NSAttributedString? {
            startedSignal.signal()
            allowFinishSignal.wait()
            guard let storedResult else { return nil }
            return NSAttributedString(attributedString: storedResult)
        }
    }

    final class CapturingSink: CodeBlockHighlightSink, @unchecked Sendable {
        private let lock = NSLock()
        private var appliedCountValue = 0

        var appliedCount: Int {
            lock.withLock { appliedCountValue }
        }

        func apply(highlightedCode: HighlightedCodeSnapshot) {
            lock.withLock { appliedCountValue += 1 }
        }
    }
}
