import UIKit
import XCTest
@testable import QuillCore
@testable import QuillKit

final class StreamingPerformanceTests: XCTestCase {
    private static let batchedCycleCount = 10

    // MARK: - Diagnostic

    @MainActor
    func testStreamingBatchedAppendThroughput() {
        let chunks = loadReplayChunks()
        let options = XCTMeasureOptions()
        options.iterationCount = 20

        for _ in 0..<Self.batchedCycleCount {
            let warmup = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
            for chunk in chunks { warmup.append(chunk) }
            warmup.finish()
        }

        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<Self.batchedCycleCount {
                let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
                for chunk in chunks {
                    view.append(chunk)
                }
                view.finish()
            }
        }
    }

    // MARK: - Candidate baseline

    @MainActor
    func testStreamingLargeDocumentAppend() {
        let source = loadFixture(named: "benchmark-mixed-10kb")
        let chunks = splitIntoChunks(source, targetChunkSize: 200)

        for _ in 0..<Self.batchedCycleCount {
            let warmup = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
            for chunk in chunks { warmup.append(chunk) }
            warmup.finish()
        }

        measure(metrics: [XCTClockMetric()]) {
            for _ in 0..<Self.batchedCycleCount {
                let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
                for chunk in chunks {
                    view.append(chunk)
                }
                view.finish()
            }
        }
    }

    @MainActor
    func testStreamBatchedResetAndRestartPerformance() {
        let chunks = loadReplayChunks()
        let firstBatch = Array(chunks.prefix(20))
        let options = XCTMeasureOptions()
        options.iterationCount = 20

        for _ in 0..<Self.batchedCycleCount {
            let warmup = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
            for chunk in firstBatch { warmup.append(chunk) }
            warmup.reset()
            for chunk in firstBatch { warmup.append(chunk) }
            warmup.finish()
        }

        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<Self.batchedCycleCount {
                let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
                for chunk in firstBatch {
                    view.append(chunk)
                }
                view.reset()
                for chunk in firstBatch {
                    view.append(chunk)
                }
                view.finish()
            }
        }
    }
}

private extension StreamingPerformanceTests {
    func loadReplayChunks() -> [String] {
        guard let url = Bundle.module.url(
            forResource: "benchmark-prose-replay",
            withExtension: "json",
            subdirectory: "Fixtures"
        ) else {
            XCTFail("Missing fixture: benchmark-prose-replay.json")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([String].self, from: data)
        } catch {
            XCTFail("Failed to load replay fixture: \(error)")
            return []
        }
    }

    func splitIntoChunks(_ source: String, targetChunkSize: Int) -> [String] {
        var chunks: [String] = []
        var remaining = source[source.startIndex...]

        while !remaining.isEmpty {
            let endOffset = min(targetChunkSize, remaining.count)
            var splitIndex = remaining.index(remaining.startIndex, offsetBy: endOffset)

            if splitIndex < remaining.endIndex {
                let searchRange = remaining.startIndex..<splitIndex
                if let newlineIndex = remaining[searchRange].lastIndex(of: "\n") {
                    splitIndex = remaining.index(after: newlineIndex)
                }
            }

            chunks.append(String(remaining[remaining.startIndex..<splitIndex]))
            remaining = remaining[splitIndex...]
        }

        return chunks
    }
}
