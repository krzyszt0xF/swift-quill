import QuillCore
@testable import QuillKit
import Testing

@Suite("FlowSegmentBuilder")
struct FlowSegmentBuilderTests {
    @Test("Empty input produces empty output")
    func emptyInput() {
        let result = FlowSegmentBuilder.build(from: [])
        #expect(result == [])
    }

    @Test("All flow blocks produce a single flow segment")
    func allFlowBlocks() {
        let blocks: [Block] = [simpleParagraph(), simpleHeading(), simpleParagraph("end")]
        let result = FlowSegmentBuilder.build(from: blocks)

        #expect(result.count == 1)
        #expect(flowBlocks(result[0]) == blocks)
    }

    @Test("Structural block splits surrounding flow blocks")
    func structuralBlockSplitsFlow() {
        let blocks: [Block] = [simpleParagraph(), simpleCodeBlock(), simpleParagraph("after")]
        let result = FlowSegmentBuilder.build(from: blocks)

        #expect(result.count == 3)
        #expect(flowBlocks(result[0]) == [simpleParagraph()])
        #expect(result[1] == .codeBlock(language: "swift", code: "let x = 1"))
        #expect(flowBlocks(result[2]) == [simpleParagraph("after")])
    }

    @Test("Consecutive structural blocks produce individual nodes")
    func consecutiveStructuralBlocks() {
        let blocks: [Block] = [simpleCodeBlock("a"), simpleCodeBlock("b")]
        let result = FlowSegmentBuilder.build(from: blocks)

        #expect(result.count == 2)
        #expect(result[0] == .codeBlock(language: "swift", code: "a"))
        #expect(result[1] == .codeBlock(language: "swift", code: "b"))
    }

    @Test("Soft cap splits long run at 10 blocks")
    func softCapSplitsLongRun() {
        let blocks = (0..<12).map { simpleParagraph("p\($0)") }
        let result = FlowSegmentBuilder.build(from: blocks)

        #expect(result.count == 2)
        #expect(flowBlocks(result[0])?.count == 10)
        #expect(flowBlocks(result[1])?.count == 2)
    }

    @Test("Mixed document groups flow blocks correctly")
    func mixedDocument() {
        let blocks: [Block] = [
            simpleHeading("intro"),
            simpleParagraph("body"),
            simpleCodeBlock("x = 1"),
            simpleParagraph("after"),
            .thematicBreak,
        ]
        let result = FlowSegmentBuilder.build(from: blocks)

        #expect(result.count == 3)
        #expect(flowBlocks(result[0]) == [simpleHeading("intro"), simpleParagraph("body")])
        #expect(result[1] == .codeBlock(language: "swift", code: "x = 1"))
        #expect(flowBlocks(result[2]) == [simpleParagraph("after"), .thematicBreak])
    }

    @Test("Single structural block produces one node")
    func singleStructuralBlock() {
        let result = FlowSegmentBuilder.build(from: [simpleCodeBlock()])
        #expect(result.count == 1)
        #expect(result[0] == .codeBlock(language: "swift", code: "let x = 1"))
    }

    @Test("Flow blocks after structural block group together")
    func flowBlocksOnlyAtEnd() {
        let blocks: [Block] = [simpleCodeBlock(), simpleParagraph("a"), simpleParagraph("b")]
        let result = FlowSegmentBuilder.build(from: blocks)

        #expect(result.count == 2)
        #expect(result[0] == .codeBlock(language: "swift", code: "let x = 1"))
        #expect(flowBlocks(result[1]) == [simpleParagraph("a"), simpleParagraph("b")])
    }

    @Test("Frozen node count respects flow soft cap")
    func frozenNodeCountRespectsSoftCap() {
        let blocks = (0..<12).map { simpleParagraph("p\($0)") }

        #expect(FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: 10) == 1)
        #expect(FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: 11) == 1)
        #expect(FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: 12) == 2)
    }

    @Test("Frozen node count drops flow segment spanning frozen boundary")
    func frozenNodeCountDropsSpanningFlowSegment() {
        let blocks: [Block] = [
            simpleParagraph("a0"),
            simpleParagraph("a1"),
            simpleParagraph("a2"),
            simpleParagraph("a3"),
            simpleParagraph("a4"),
            simpleParagraph("a5"),
            simpleParagraph("a6"),
            simpleParagraph("a7"),
            simpleParagraph("a8"),
            simpleParagraph("a9"),
            simpleParagraph("a10"),
            simpleParagraph("a11"),
            simpleCodeBlock("let x = 1"),
        ]

        #expect(FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: 11) == 1)
        #expect(FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: 12) == 2)
        #expect(FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: 13) == 3)
    }
}

private extension FlowSegmentBuilderTests {
    func flowBlocks(_ node: RenderNode) -> [Block]? {
        if case let .flow(segment) = node {
            return segment.blocks
        }
        
        return nil
    }

    func simpleCodeBlock(_ code: String = "let x = 1", language: String? = "swift") -> Block {
        .codeBlock(language: language, code: code)
    }

    func simpleHeading(_ text: String = "title", level: Int = 1) -> Block {
        .heading(level: level, content: [.text(text)])
    }

    func simpleParagraph(_ text: String = "test") -> Block {
        .paragraph(content: [.text(text)])
    }

    func simpleTable() -> Block {
        .table(
            columnAlignments: [.left],
            header: Block.TableRow(cells: [Block.TableCell(content: [.text("h")])]),
            rows: [Block.TableRow(cells: [Block.TableCell(content: [.text("r")])])]
        )
    }
}
