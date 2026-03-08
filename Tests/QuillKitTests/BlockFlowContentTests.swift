import QuillCore
import QuillKit
import Testing

@Suite("Block.isFlowContent classification")
struct BlockFlowContentTests {
    struct BlockFlowCase: CustomTestStringConvertible {
        let block: Block
        let expected: Bool
        let testDescription: String
    }

    @Test("classifies all Block cases correctly", arguments: [
        BlockFlowCase(
            block: .blockquote(children: []),
            expected: true,
            testDescription: "blockquote"
        ),
        BlockFlowCase(
            block: .codeBlock(language: nil, code: ""),
            expected: false,
            testDescription: "codeBlock"
        ),
        BlockFlowCase(
            block: .heading(level: 1, content: []),
            expected: true,
            testDescription: "heading"
        ),
        BlockFlowCase(
            block: .htmlBlock(rawHTML: ""),
            expected: true,
            testDescription: "htmlBlock"
        ),
        BlockFlowCase(
            block: .orderedList(startIndex: 1, items: []),
            expected: true,
            testDescription: "orderedList"
        ),
        BlockFlowCase(
            block: .paragraph(content: []),
            expected: true,
            testDescription: "paragraph"
        ),
        BlockFlowCase(
            block: .table(columnAlignments: [], header: Block.TableRow(cells: []), rows: []),
            expected: false,
            testDescription: "table"
        ),
        BlockFlowCase(
            block: .thematicBreak,
            expected: true,
            testDescription: "thematicBreak"
        ),
        BlockFlowCase(
            block: .unorderedList(items: []),
            expected: true,
            testDescription: "unorderedList"
        ),
    ])
    func blockFlowContent(_ testCase: BlockFlowCase) {
        #expect(testCase.block.isFlowContent == testCase.expected)
    }
}
