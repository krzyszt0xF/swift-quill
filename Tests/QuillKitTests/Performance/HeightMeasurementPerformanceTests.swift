import UIKit
import XCTest
@testable import QuillCore
@testable import QuillKit

final class HeightMeasurementPerformanceTests: XCTestCase {
    // MARK: - Strict baseline

    @MainActor
    func testHeightMeasurementAfterStreamingPerformance() {
        let source = loadFixture(named: "benchmark-prose-long")
        let chunks = splitIntoChunks(source, count: 30)

        let warmup = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        for chunk in chunks { warmup.append(chunk) }
        warmup.finish()
        warmup.layoutIfNeeded()

        measure(metrics: [XCTClockMetric()]) {
            let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
            for chunk in chunks {
                view.append(chunk)
            }
            view.finish()
            view.layoutIfNeeded()
        }
    }

    // MARK: - Diagnostic

    @MainActor
    func testHeightInvalidationOnWidthChangePerformance() {
        let source = loadFixture(named: "benchmark-mixed-10kb")
        let blocks = MarkdownParser.live.parse(source)

        let renderer = DocumentRenderer.live
        _ = renderer.render(blocks: blocks, frozenCount: blocks.count)

        let textView = renderer.textView
        let widths: [CGFloat] = [320, 360, 414, 375, 390]
        let options = XCTMeasureOptions()
        options.iterationCount = 10

        for width in widths {
            textView.frame = CGRect(x: 0, y: 0, width: width, height: 800)
            textView.invalidateIntrinsicContentSize()
            _ = textView.intrinsicContentSize.height
            textView.layoutIfNeeded()
        }

        measure(metrics: [XCTClockMetric()], options: options) {
            for width in widths {
                textView.frame = CGRect(x: 0, y: 0, width: width, height: 800)
                textView.invalidateIntrinsicContentSize()
                _ = textView.intrinsicContentSize.height
                textView.layoutIfNeeded()
            }
        }
    }
}

private extension HeightMeasurementPerformanceTests {
    func splitIntoChunks(_ source: String, count: Int) -> [String] {
        let chunkSize = max(1, source.count / count)
        var chunks: [String] = []
        var remaining = source[source.startIndex...]

        while !remaining.isEmpty {
            let endOffset = min(chunkSize, remaining.count)
            let splitIndex = remaining.index(remaining.startIndex, offsetBy: endOffset)
            chunks.append(String(remaining[remaining.startIndex..<splitIndex]))
            remaining = remaining[splitIndex...]
        }

        return chunks
    }
}
