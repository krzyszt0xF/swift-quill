import Foundation
import Testing
@testable import QuillCore

@Suite("ModuleStreamGate heuristic validation")
struct ModuleStreamGateValidationTests {
    @Test("Fast prose commits at reasonable intervals")
    func fastProseCommitsAtReasonableIntervals() {
        let chunks = makeFastProseChunks(count: 200)
        var gate = ModuleStreamGate()
        var now: TimeInterval = 0
        var allCommitted: [String] = []
        var commitCount = 0

        for chunk in chunks {
            now += 0.020
            let result = gate.append(chunk, now: now)
            if !result.committedChunks.isEmpty {
                allCommitted.append(contentsOf: result.committedChunks)
                commitCount += 1
            }
        }

        let remaining = gate.flushRemaining()
        if !remaining.isEmpty {
            allCommitted.append(remaining)
        }

        let totalInput = chunks.joined()
        let totalOutput = allCommitted.joined()
        #expect(totalOutput == totalInput)
        #expect(commitCount > 0, "Should produce commits before final flush")
        #expect(commitCount < chunks.count, "Should not commit after every chunk")
    }

    @Test("Slow drip still commits incrementally before final flush")
    func slowDripCommitsIncrementallyBeforeFinalFlush() {
        let chunks = makeSlowDripChunks(count: 30)
        var gate = ModuleStreamGate()
        var now: TimeInterval = 0
        var allCommitted: [String] = []
        var appendCommitCount = 0
        var timeoutCommitCount = 0

        for chunk in chunks {
            now += 0.200
            let result = gate.append(chunk, now: now)
            if !result.committedChunks.isEmpty {
                allCommitted.append(contentsOf: result.committedChunks)
                appendCommitCount += 1
            }

            let overdueChunks = gate.commitIfOverdue(now: now + 1.6)
            if !overdueChunks.isEmpty {
                allCommitted.append(contentsOf: overdueChunks)
                timeoutCommitCount += 1
            }
        }

        let remaining = gate.flushRemaining()
        if !remaining.isEmpty {
            allCommitted.append(remaining)
        }

        let totalInput = chunks.joined()
        let totalOutput = allCommitted.joined()
        #expect(totalOutput == totalInput)
        #expect(
            appendCommitCount + timeoutCommitCount >= 1,
            "Slow drip should still produce incremental commits before final flush"
        )
        #expect(
            appendCommitCount + timeoutCommitCount < chunks.count,
            "Slow drip should not commit after every append"
        )
    }

    @Test("Structure-heavy content commits at heading boundaries")
    func structureHeavyContentCommitsAtHeadingBoundaries() {
        let chunks = makeStructureHeavyChunks()
        var gate = ModuleStreamGate()
        var now: TimeInterval = 0
        var allCommitted: [String] = []
        var commitCount = 0

        for chunk in chunks {
            now += 0.020
            let result = gate.append(chunk, now: now)
            if !result.committedChunks.isEmpty {
                allCommitted.append(contentsOf: result.committedChunks)
                commitCount += 1
            }
        }

        let remaining = gate.flushRemaining()
        if !remaining.isEmpty {
            allCommitted.append(remaining)
        }

        let totalInput = chunks.joined()
        let totalOutput = allCommitted.joined()
        #expect(totalOutput == totalInput)
        #expect(commitCount > 0, "Should produce structural boundary commits")

        let headingCommitCount = allCommitted.filter { committed in
            committed.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#")
        }.count
        #expect(headingCommitCount > 0, "At least some commits should start at heading boundaries")
    }

    @Test("Code fence blocks are buffered until close")
    func codeFenceBlocksBufferedUntilClose() {
        let codeFenceChunks = [
            "Some text before the code.\n\n",
            "```swift\n",
            "func example() {\n",
            "    let value = 42\n",
            "    print(value)\n",
            "}\n",
            "```\n\n",
            "Text after the code block.\n\n",
        ]

        var gate = ModuleStreamGate()
        var now: TimeInterval = 0
        var commitsWhileFenceOpen: [String] = []
        var allCommitted: [String] = []
        var fenceIsOpen = false

        for chunk in codeFenceChunks {
            now += 0.020
            let result = gate.append(chunk, now: now)

            if chunk.hasPrefix("```swift") {
                fenceIsOpen = true
            }
            if chunk.trimmingCharacters(in: .whitespacesAndNewlines) == "```", fenceIsOpen {
                fenceIsOpen = false
            }

            if fenceIsOpen, !result.committedChunks.isEmpty {
                commitsWhileFenceOpen.append(contentsOf: result.committedChunks)
            }
            allCommitted.append(contentsOf: result.committedChunks)
        }

        let remaining = gate.flushRemaining()
        if !remaining.isEmpty {
            allCommitted.append(remaining)
        }

        let totalInput = codeFenceChunks.joined()
        let totalOutput = allCommitted.joined()
        #expect(totalOutput == totalInput)

        #expect(commitsWhileFenceOpen.isEmpty, "Zero commits should occur while code fence is open, got \(commitsWhileFenceOpen.count)")
    }

    @Test("Tables are buffered until complete")
    func tablesAreBufferedUntilComplete() {
        let tableChunks = [
            "Intro paragraph before table.\n\n",
            "| Column A | Column B |\n",
            "|:---------|:---------|\n",
            "| cell 1a  | cell 1b  |\n",
            "| cell 2a  | cell 2b  |\n",
            "\n",
            "After the table.\n\n",
        ]

        var gate = ModuleStreamGate()
        var now: TimeInterval = 0
        var commitsBeforeTableEnd: [String] = []
        var allCommitted: [String] = []
        var tableStarted = false

        for chunk in tableChunks {
            now += 0.020
            let result = gate.append(chunk, now: now)

            if chunk.hasPrefix("|") {
                tableStarted = true
            }
            let isTableTerminator = chunk == "\n" && tableStarted

            if tableStarted, !isTableTerminator, !result.committedChunks.isEmpty {
                let rowCommits = result.committedChunks.filter { $0.contains("|") }
                commitsBeforeTableEnd.append(contentsOf: rowCommits)
            }
            if isTableTerminator {
                tableStarted = false
            }

            allCommitted.append(contentsOf: result.committedChunks)
        }

        let tableRemaining = gate.flushRemaining()
        if !tableRemaining.isEmpty {
            allCommitted.append(tableRemaining)
        }

        let tableInput = tableChunks.joined()
        let tableOutput = allCommitted.joined()
        #expect(tableOutput == tableInput)
        let commitCount = commitsBeforeTableEnd.count
        #expect(
            commitsBeforeTableEnd.isEmpty,
            "No table row content should be committed before the table ends, got \(commitCount)"
        )
    }

    @Test("Default heuristics handle mixed content without pathological buffering")
    func defaultHeuristicsHandleMixedContent() {
        let mixedChunks = makeMixedContentChunks(targetChunkCount: 100)
        var gate = ModuleStreamGate()
        var now: TimeInterval = 0
        var allCommitted: [String] = []
        var commitCallCount = 0

        for chunk in mixedChunks {
            now += 0.020
            let result = gate.append(chunk, now: now)
            if !result.committedChunks.isEmpty {
                allCommitted.append(contentsOf: result.committedChunks)
                commitCallCount += 1
            }
        }

        let remaining = gate.flushRemaining()
        if !remaining.isEmpty {
            allCommitted.append(remaining)
        }

        let totalInput = mixedChunks.joined()
        let totalOutput = allCommitted.joined()
        #expect(totalOutput == totalInput, "No data loss: total committed must equal total input")
        #expect(commitCallCount > 0, "Should not buffer everything until final flush")
        #expect(commitCallCount < mixedChunks.count, "Should not commit after every single chunk")
    }
}

private extension ModuleStreamGateValidationTests {
    func makeFastProseChunks(count: Int) -> [String] {
        let sentences = [
            "The quick brown fox ",
            "jumps over the lazy dog. ",
            "Swift concurrency makes ",
            "async code safer. ",
            "Actors protect mutable state.\n\n",
            "Markdown rendering requires ",
            "careful incremental updates ",
            "to maintain smooth scrolling. ",
            "The pipeline processes chunks ",
            "as they arrive from the model.\n\n",
        ]
        return (0..<count).map { index in
            sentences[index % sentences.count]
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
        chunks.append("# Introduction\n\nThis document covers multiple topics.\n\n")
        chunks.append("## First Section\n\nContent for the first section with enough text to exceed the minimum module length.\n\n")
        chunks.append("# Main Topic\n\nThe main topic has detailed content spanning multiple paragraphs.\n\n")
        chunks.append("## Subtopic A\n\nSubtopic A provides context for the reader.\n\n")
        chunks.append("# Another Heading\n\nThis heading starts a new major section of the document.\n\n")
        chunks.append("## Sub Detail\n\nMore detailed content under another heading with extra words to meet length.\n\n")
        chunks.append("# Final Section\n\nThe final section wraps up the document with concluding remarks.\n\n")
        return chunks
    }

    func makeMixedContentChunks(targetChunkCount: Int) -> [String] {
        var chunks: [String] = []

        chunks.append("# Overview\n\n")
        chunks.append("This document demonstrates mixed markdown content ")
        chunks.append("with prose, headings, code blocks, and tables.\n\n")

        chunks.append("## Code Example\n\n")
        chunks.append("```swift\n")
        chunks.append("struct Pipeline {\n")
        chunks.append("    func process() {\n")
        chunks.append("        print(\"running\")\n")
        chunks.append("    }\n")
        chunks.append("}\n")
        chunks.append("```\n\n")

        chunks.append("The code above shows a simple pipeline structure.\n\n")

        chunks.append("## Data Table\n\n")
        chunks.append("| Stage    | Owner              | Isolation |\n")
        chunks.append("|:---------|:-------------------|:----------|\n")
        chunks.append("| Parse    | StreamController    | Actor     |\n")
        chunks.append("| Reduce   | StreamCoordinator   | MainActor |\n")
        chunks.append("| Render   | DocumentRenderer    | MainActor |\n")
        chunks.append("\n")

        chunks.append("# Conclusion\n\n")
        chunks.append("The pipeline processes markdown efficiently. ")
        chunks.append("Each stage has clear ownership and isolation. ")
        chunks.append("Performance benchmarks validate the heuristics.\n\n")

        while chunks.count < targetChunkCount {
            chunks.append("Additional prose content to reach the target chunk count. ")
            if chunks.count % 10 == 0 {
                chunks.append("\n\n")
            }
        }

        return Array(chunks.prefix(targetChunkCount))
    }
}
