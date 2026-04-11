import XCTest
@testable import QuillCore

final class ParsePerformanceTests: XCTestCase {
    private static let batchedParseCount = 50

    private var mixedFixture: String!
    private var richFixture: String!
    private var structureFixture: String!

    override func setUp() {
        super.setUp()
        mixedFixture = loadFixture(named: "benchmark-mixed-10kb")
        structureFixture = loadFixture(named: "benchmark-structure-heavy")
        richFixture = loadFixture(named: "benchmark-rich-content")
    }

    override func tearDown() {
        mixedFixture = nil
        structureFixture = nil
        richFixture = nil
        super.tearDown()
    }

    // MARK: - Diagnostic

    func testParseLargeMixedDocumentPerformance() {
        let source = mixedFixture!
        let batchCount = 20
        let options = XCTMeasureOptions()
        options.iterationCount = 20

        for _ in 0..<batchCount {
            _ = MarkdownParser.live.parse(source)
        }

        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<batchCount {
                _ = MarkdownParser.live.parse(source)
            }
        }
    }

    // MARK: - Candidate baselines

    func testParseStructureHeavyDocumentPerformance() {
        let source = structureFixture!
        let options = XCTMeasureOptions()
        options.iterationCount = 20

        for _ in 0..<Self.batchedParseCount {
            _ = MarkdownParser.live.parse(source)
        }

        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<Self.batchedParseCount {
                _ = MarkdownParser.live.parse(source)
            }
        }
    }

    func testParseRichContentDocumentPerformance() {
        let source = richFixture!
        let options = XCTMeasureOptions()
        options.iterationCount = 20

        for _ in 0..<Self.batchedParseCount {
            _ = MarkdownParser.live.parse(source)
        }

        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<Self.batchedParseCount {
                _ = MarkdownParser.live.parse(source)
            }
        }
    }

    func testParseRepeatedSmallDocumentsPerformance() {
        let source = """
        # Quick Heading

        A short paragraph with **bold** and *italic* text.

        - Item one
        - Item two
          - Nested item
        """
        let options = XCTMeasureOptions()
        options.iterationCount = 20

        for _ in 0..<100 {
            _ = MarkdownParser.live.parse(source)
        }

        measure(metrics: [XCTClockMetric()], options: options) {
            for _ in 0..<100 {
                _ = MarkdownParser.live.parse(source)
            }
        }
    }
}

private extension ParsePerformanceTests {
    func loadFixture(named name: String) -> String {
        guard let url = Bundle.module.url(
            forResource: name,
            withExtension: "md",
            subdirectory: "Fixtures"
        ) else {
            XCTFail("Missing fixture: \(name).md")
            return ""
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            XCTFail("Failed to load fixture \(name).md: \(error)")
            return ""
        }
    }
}
