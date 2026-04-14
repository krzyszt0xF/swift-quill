import XCTest
@testable import QuillCore

final class ModuleStreamGatePerformanceTests: XCTestCase {
    func testGateAppendFastProsePerformance() {
        let proseChunks = makeFastProseChunks(count: 500)
        measure(metrics: [XCTClockMetric()]) {
            var gate = ModuleStreamGate()
            var now: TimeInterval = 0
            for chunk in proseChunks {
                now += 0.015
                _ = gate.append(chunk, now: now)
            }
            _ = gate.flushRemaining()
        }
    }

    func testGateAppendSlowDripPerformance() {
        let dripChunks = makeSlowDripChunks(count: 50)
        measure(metrics: [XCTClockMetric()]) {
            var gate = ModuleStreamGate()
            var now: TimeInterval = 0
            for chunk in dripChunks {
                now += 0.3
                let result = gate.append(chunk, now: now)
                if result.committedChunks.isEmpty {
                    let committed = gate.commitIfOverdue(now: now + 1.6)
                    _ = committed
                }
            }
            _ = gate.flushRemaining()
        }
    }

    func testGateStructureHeavyPerformance() {
        let structureChunks = makeStructureHeavyChunks()
        measure(metrics: [XCTClockMetric()]) {
            var gate = ModuleStreamGate()
            var now: TimeInterval = 0
            for chunk in structureChunks {
                now += 0.02
                _ = gate.append(chunk, now: now)
            }
            _ = gate.flushRemaining()
        }
    }

    func testGateCodeTableHeavyPerformance() {
        let codeTableChunks = makeCodeTableChunks()
        measure(metrics: [XCTClockMetric()]) {
            var gate = ModuleStreamGate()
            var now: TimeInterval = 0
            for chunk in codeTableChunks {
                now += 0.02
                _ = gate.append(chunk, now: now)
            }
            _ = gate.flushRemaining()
        }
    }
}

private extension ModuleStreamGatePerformanceTests {
    func makeFastProseChunks(count: Int) -> [String] {
        let words = [
            "the ", "quick ", "brown ", "fox ", "jumps ", "over ",
            "lazy ", "dog ", "and ", "then ", "runs ", "back ",
            "to ", "start ", "again.\n\n"
        ]
        return (0..<count).map { index in
            words[index % words.count]
        }
    }

    func makeSlowDripChunks(count: Int) -> [String] {
        let templates = [
            "This is a longer chunk of text that simulates a slow token drip from a language model. ",
            "The model takes its time generating each piece of content, producing substantial blocks. ",
            "Each chunk contains multiple words and sometimes even complete sentences worth of content. ",
            "Slow drip scenarios exercise the timeout commit path in the gate heuristics logic. ",
            "The buffering delay threshold determines when held content is force-committed to render.\n\n",
        ]
        return (0..<count).map { index in
            templates[index % templates.count]
        }
    }

    func makeStructureHeavyChunks() -> [String] {
        var chunks: [String] = []
        for section in 0..<20 {
            chunks.append("## Section \(section)\n\n")
            chunks.append("Brief intro paragraph for section \(section).\n\n")
            chunks.append("- List item one in section \(section)\n")
            chunks.append("- List item two in section \(section)\n")
            chunks.append("  - Nested item under two\n")
            chunks.append("- List item three\n\n")
            chunks.append("> A blockquote in section \(section) providing additional context.\n\n")
        }
        return chunks
    }

    func makeCodeTableChunks() -> [String] {
        var chunks: [String] = []
        for block in 0..<10 {
            chunks.append("Some text before code block \(block).\n\n")
            chunks.append("```swift\n")
            chunks.append("func example\(block)() {\n")
            chunks.append("    let value = \(block)\n")
            chunks.append("    print(value)\n")
            chunks.append("}\n")
            chunks.append("```\n\n")
            chunks.append("| Column A | Column B | Column C |\n")
            chunks.append("|:---------|:---------|:---------|\n")
            for row in 0..<4 {
                chunks.append("| cell \(block)-\(row)a | cell \(block)-\(row)b | cell \(block)-\(row)c |\n")
            }
            chunks.append("\n")
        }
        return chunks
    }
}
