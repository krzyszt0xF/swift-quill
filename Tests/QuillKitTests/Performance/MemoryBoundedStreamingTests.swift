import UIKit
import XCTest
@testable import QuillKit

final class MemoryBoundedStreamingTests: XCTestCase {
    // MARK: - Strict baseline

    @MainActor
    func testStreamingMemorySmokeAcrossResets() {
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        let proseChunks = makeProseChunks(count: 50)

        measure(metrics: [XCTMemoryMetric()]) {
            for _ in 0..<3 {
                autoreleasepool {
                    for chunk in proseChunks {
                        view.append(chunk)
                    }
                    view.finish()
                    view.reset()
                }
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            }
        }
    }

    // MARK: - Behavioral

    @MainActor
    func testCanceledStreamsDoNotRetainResources() {
        let chunks = makeProseChunks(count: 20)

        weak var weakView: QuillView?

        autoreleasepool {
            let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
            weakView = view

            for chunk in chunks.prefix(10) {
                view.append(chunk)
            }
            view.finish()
            view.reset()
        }
        waitForDeallocation { weakView }

        XCTAssertNil(weakView, "QuillView should deallocate after reset and scope exit")
    }

    @MainActor
    func testViewDeallocatesAfterStreamingCancel() {
        let chunks = makeProseChunks(count: 20)

        weak var weakView: QuillView?

        autoreleasepool {
            let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
            weakView = view

            for chunk in chunks.prefix(10) {
                view.append(chunk)
            }
            view.cancelStreaming()
        }
        waitForDeallocation { weakView }

        XCTAssertNil(weakView, "QuillView should deallocate after cancelStreaming and scope exit")
    }
}

private extension MemoryBoundedStreamingTests {
    func waitForDeallocation(
        timeout: TimeInterval = 0.5,
        _ object: () -> AnyObject?
    ) {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while object() != nil, Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    func makeProseChunks(count: Int) -> [String] {
        let sentences = [
            "The rendering pipeline processes markdown content incrementally. ",
            "Each chunk arrives from the language model and is appended to the buffer. ",
            "The gate heuristics determine when buffered content is committed for rendering. ",
            "Structural boundaries like headings and paragraph breaks create natural commit points. ",
            "Code fences and tables are buffered until their structure is complete.\n\n",
        ]
        return (0..<count).map { index in
            sentences[index % sentences.count]
        }
    }
}
