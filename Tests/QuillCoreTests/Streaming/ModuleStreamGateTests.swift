@testable import QuillCore
import QuillSharedTestSupport
import Testing

@Suite("ModuleStreamGate", .tags(.streaming))
struct ModuleStreamGateTests {
    @Test("Commits modules at heading boundaries")
    func headingBoundaryCommit() throws {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 10, maxBufferingDelay: 1.5)
        )

        let markdown = """
        # First
        alpha

        # Second
        beta

        """ + "\n"

        let result = gate.append(markdown, now: 0)
        #expect(result.committedChunks.count == 2)
        try #require(result.committedChunks.count == 2)
        #expect(result.committedChunks[0].contains("# First"))
        #expect(result.committedChunks[1].contains("# Second"))
        #expect(result.hasPendingText == false)
    }

    @Test("Commits long paragraph fallback after double newline")
    func paragraphFallbackCommit() throws {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 12, maxBufferingDelay: 1.5)
        )

        let text = """
        This is a long paragraph without headings and with enough content to pass the threshold.

        """ + "\n"

        let result = gate.append(text, now: 0)
        #expect(result.committedChunks.count == 1)
        let firstCommitted = try #require(result.committedChunks.first)
        #expect(firstCommitted.contains("long paragraph"))
        #expect(result.hasPendingText == false)
    }

    @Test("Blocks commit while code fence or table is pending")
    func pendingStructureBlocksCommit() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 10, maxBufferingDelay: 1.5)
        )

        let openCode = gate.append("```swift\nlet x = 1\n", now: 0)
        #expect(openCode.committedChunks.isEmpty)
        #expect(openCode.hasPendingStructure)
        #expect(gate.commitIfOverdue(now: 2.0).isEmpty)

        let openTable = gate.append(
            """
            | name | value |
            | --- | --- |
            | a | 1 |
            """,
            now: 2.2
        )
        #expect(openTable.hasPendingStructure)
    }

    @Test("Flush returns pending raw content and clears state")
    func flushRemaining() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 50, maxBufferingDelay: 1.5)
        )

        _ = gate.append("Pending tail without boundary", now: 0)
        let remaining = gate.flushRemaining()

        #expect(remaining == "Pending tail without boundary")
        #expect(gate.hasPendingText == false)
    }

    @Test("Overdue commit uses safe newline boundary")
    func overdueCommitUsesSafeBoundary() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 8, maxBufferingDelay: 1.5)
        )

        _ = gate.append(
            """
            line one
            line two
            line three
            line four
            """,
            now: 0
        )

        let committed = gate.commitIfOverdue(now: 1.6)
        #expect(committed.isEmpty == false)
        #expect(committed.joined().contains("line three"))
    }

    @Test("Overdue commit does not emit tiny chunks below safety threshold")
    func overdueCommitBlocksTinyChunks() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 30, maxBufferingDelay: 1.5)
        )

        _ = gate.append("short pending text without safe boundary", now: 0)

        let committed = gate.commitIfOverdue(now: 1.6)
        #expect(committed.isEmpty)
        #expect(gate.hasPendingText)
    }

    @Test("Overdue commit prefers double newline boundary when available")
    func overdueCommitPrefersDoubleNewlineBoundary() throws {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 30, maxBufferingDelay: 1.5)
        )

        let markdown = """
        alpha section
        beta section

        gamma section
        """

        let appendResult = gate.append(markdown, now: 0)
        #expect(appendResult.committedChunks.isEmpty)

        gate.updateConfiguration(.init(minModuleLength: 8, maxBufferingDelay: 1.5))

        let committed = gate.commitIfOverdue(now: 1.6)
        #expect(committed.count == 1)
        try #require(committed.count == 1)
        #expect(committed[0].contains("beta section"))
        #expect(committed[0].contains("gamma section") == false)
    }

    @Test("Overdue single-newline commit requires larger buffer")
    func overdueSingleNewlineNeedsLargerBuffer() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 10, maxBufferingDelay: 1.5)
        )

        _ = gate.append("a\nb\nc\nshort", now: 0)
        #expect(gate.commitIfOverdue(now: 1.6).isEmpty)

        _ = gate.append("\n\(String(repeating: "x", count: 60))", now: 1.7)
        let committed = gate.commitIfOverdue(now: 3.3)
        #expect(committed.isEmpty == false)
    }

    @Test("Commits using latest paragraph boundary even if stream tail is unfinished")
    func commitsOnLatestParagraphBoundaryWithUnfinishedTail() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 40, maxBufferingDelay: 1.5)
        )

        let first = gate.append(
            """
            Paragraph one line one.
            Paragraph one line two.

            Paragraph two line one.
            Paragraph two line two.

            """,
            now: 0
        )

        #expect(first.committedChunks.isEmpty == false)

        let second = gate.append(
            """
            Paragraph three line one.
            Paragraph three line two.

            Paragraph four starts but has no final delimiter yet
            """,
            now: 0.2
        )

        #expect(second.committedChunks.isEmpty == false)
        let latestCommit = second.committedChunks.joined()
        #expect(latestCommit.contains("Paragraph three line two."))
        #expect(latestCommit.contains("Paragraph four starts") == false)
        #expect(gate.hasPendingText)
    }

    @Test("Chunked appends preserve same committed output as single append")
    func chunkedAppendsMatchSingleAppend() {
        let markdown = """
        # Intro
        alpha

        ## Details
        beta

        ## More
        gamma

        """

        var singleGate = ModuleStreamGate(
            configuration: .init(minModuleLength: 10, maxBufferingDelay: 1.5)
        )
        let singleResult = singleGate.append(markdown, now: 0)
        let singleFlush = singleGate.flushRemaining()

        var chunkedGate = ModuleStreamGate(
            configuration: .init(minModuleLength: 10, maxBufferingDelay: 1.5)
        )
        let chunks = ["# Intro\nalp", "ha\n\n## Details\nbe", "ta\n\n## More\ngamma\n\n"]
        var chunkedCommits: [String] = []

        for (index, chunk) in chunks.enumerated() {
            let result = chunkedGate.append(chunk, now: Double(index) * 0.1)
            chunkedCommits.append(contentsOf: result.committedChunks)
        }

        let chunkedFlush = chunkedGate.flushRemaining()
        let singleOutput = singleResult.committedChunks.joined() + singleFlush
        let chunkedOutput = chunkedCommits.joined() + chunkedFlush

        #expect(normalizeTerminalNewlines(in: chunkedOutput) == normalizeTerminalNewlines(in: singleOutput))
    }

    @Test("Split code fence keeps pending structure until closed")
    func splitCodeFenceKeepsPendingStructureUntilClosed() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 10, maxBufferingDelay: 1.5)
        )

        let first = gate.append("```", now: 0)
        let second = gate.append("swift\nlet x = 1\n", now: 0.1)
        let third = gate.append("```\n\n# Next\nbody\n\n", now: 0.2)

        #expect(first.hasPendingStructure)
        #expect(first.committedChunks.isEmpty)
        #expect(second.hasPendingStructure)
        #expect(second.committedChunks.isEmpty)
        #expect(third.hasPendingStructure == false)
        #expect(third.committedChunks.isEmpty == false)
        #expect(third.committedChunks.joined().contains("let x = 1"))
    }

    @Test("Reset clears rebuilt analysis after committed prefix compaction")
    func resetClearsAnalysisAfterCompaction() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 8, maxBufferingDelay: 1.5)
        )

        _ = gate.append(
            """
            # First
            alpha

            # Second
            beta

            """,
            now: 0
        )

        gate.reset()

        let result = gate.append(
            "Standalone paragraph after reset.\n\n",
            now: 0.1
        )

        #expect(result.committedChunks.count == 1)
        #expect(result.committedChunks[0].contains("Standalone paragraph after reset."))
        #expect(result.hasPendingStructure == false)
    }
}

private extension ModuleStreamGateTests {
    func normalizeTerminalNewlines(in text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .newlines)
        guard text.last == "\n" else { return trimmed }
        return trimmed + "\n"
    }
}
