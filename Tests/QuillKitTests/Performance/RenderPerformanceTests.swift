import UIKit
import XCTest
@testable import QuillCore
@testable import QuillKit

final class RenderPerformanceTests: XCTestCase {
    private var mixedBlocks: [BlockNode]!
    private var richBlocks: [BlockNode]!

    override func setUp() {
        super.setUp()
        let mixedSource = loadFixture(named: "benchmark-mixed-10kb")
        let richSource = loadFixture(named: "benchmark-rich-content")
        mixedBlocks = MarkdownParser.live.parse(mixedSource)
        richBlocks = MarkdownParser.live.parse(richSource)
    }

    override func tearDown() {
        mixedBlocks = nil
        richBlocks = nil
        super.tearDown()
    }

    // MARK: - Diagnostic

    @MainActor
    func testDocumentRendererMixedDocumentPerformance() {
        let blocks = mixedBlocks!

        for _ in 0..<3 {
            let warmup = DocumentRenderer.live
            _ = warmup.render(blocks: blocks, frozenCount: blocks.count)
        }

        let options = XCTMeasureOptions()
        options.iterationCount = 10

        measure(metrics: [XCTClockMetric()], options: options) {
            let renderer = DocumentRenderer.live
            _ = renderer.render(blocks: blocks, frozenCount: blocks.count)
        }
    }

    // MARK: - Candidate baseline

    @MainActor
    func testDocumentRendererRichContentPerformance() {
        let blocks = richBlocks!

        for _ in 0..<3 {
            let warmup = DocumentRenderer.live
            _ = warmup.render(blocks: blocks, frozenCount: blocks.count)
        }

        let options = XCTMeasureOptions()
        options.iterationCount = 10

        measure(metrics: [XCTClockMetric()], options: options) {
            let renderer = DocumentRenderer.live
            _ = renderer.render(blocks: blocks, frozenCount: blocks.count)
        }
    }
}
