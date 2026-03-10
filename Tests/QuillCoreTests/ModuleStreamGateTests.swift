@testable import QuillCore
import Testing

@Suite("ModuleStreamGate")
struct ModuleStreamGateTests {
    @Test("Commits modules at heading boundaries")
    func headingBoundaryCommit() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 10, maxBufferingDelay: 1.5)
        )

        let markdown = """
        # First
        alpha

        # Second
        beta

        """

        let result = gate.append(markdown, now: 0)
        #expect(result.committedChunks.count == 2)
        #expect(result.committedChunks[0].contains("# First"))
        #expect(result.committedChunks[1].contains("# Second"))
        #expect(result.hasPendingText == false)
    }

    @Test("Commits long paragraph fallback after double newline")
    func paragraphFallbackCommit() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 12, maxBufferingDelay: 1.5)
        )

        let text = """
        This is a long paragraph without headings and with enough content to pass the threshold.

        """

        let result = gate.append(text, now: 0)
        #expect(result.committedChunks.count == 1)
        #expect(result.committedChunks[0].contains("long paragraph"))
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
    func overdueCommitPrefersDoubleNewlineBoundary() {
        var gate = ModuleStreamGate(
            configuration: .init(minModuleLength: 8, maxBufferingDelay: 1.5)
        )

        _ = gate.append(
            """
            alpha section
            beta section

            gamma section
            """,
            now: 0
        )

        let committed = gate.commitIfOverdue(now: 1.6)
        #expect(committed.count == 1)
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
}
