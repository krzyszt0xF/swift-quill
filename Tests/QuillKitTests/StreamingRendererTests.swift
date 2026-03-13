@testable import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("StreamingBlockRenderer")
struct StreamingRendererTests {
    @Test("Single paragraph creates one TextFlowView")
    func singleParagraph() {
        let renderer = StreamingBlockRenderer()
        let blocks: [Block] = [.paragraph(content: [.text("Hello")])]

        renderer.update(blocks: blocks, frozenCount: 1)

        #expect(renderer.arrangedBlockViews.count == 1)
        #expect(renderer.arrangedBlockViews[0] is TextFlowView)
    }

    @Test("Paragraph then code block creates two views")
    func paragraphThenCodeBlock() {
        let renderer = StreamingBlockRenderer()
        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]

        renderer.update(blocks: blocks, frozenCount: 2)

        #expect(renderer.arrangedBlockViews.count == 2)
        #expect(renderer.arrangedBlockViews[0] is TextFlowView)
        #expect(renderer.arrangedBlockViews[1] is CodeBlockView)
    }

    @Test("Frozen views survive when tail is added")
    func frozenViewsSurviveTailAdd() {
        let renderer = StreamingBlockRenderer()

        let blocks1: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]
        renderer.update(blocks: blocks1, frozenCount: 2)

        let frozenFlow = renderer.arrangedBlockViews[0]
        let frozenCode = renderer.arrangedBlockViews[1]

        let blocks2: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("After")]),
        ]
        renderer.update(blocks: blocks2, frozenCount: 2)

        #expect(renderer.arrangedBlockViews.count == 3)
        #expect(renderer.arrangedBlockViews[0] === frozenFlow)
        #expect(renderer.arrangedBlockViews[1] === frozenCode)
        #expect(renderer.arrangedBlockViews[2] is TextFlowView)
    }

    @Test("Frozen prefix with three structural nodes preserved across updates")
    func threeNodeFrozenPrefix() {
        let renderer = StreamingBlockRenderer()

        let blocks1: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("B")]),
        ]
        renderer.update(blocks: blocks1, frozenCount: 3)

        let view0 = renderer.arrangedBlockViews[0]
        let view1 = renderer.arrangedBlockViews[1]
        let view2 = renderer.arrangedBlockViews[2]

        let blocks2: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("B")]),
            .codeBlock(language: "py", code: "y\n"),
        ]
        renderer.update(blocks: blocks2, frozenCount: 3)

        #expect(renderer.arrangedBlockViews.count == 4)
        #expect(renderer.arrangedBlockViews[0] === view0)
        #expect(renderer.arrangedBlockViews[1] === view1)
        #expect(renderer.arrangedBlockViews[2] === view2)
    }

    @Test("Tail views are rebuilt not reused")
    func tailViewsRebuilt() {
        let renderer = StreamingBlockRenderer()

        let blocks1: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("open")]),
        ]
        renderer.update(blocks: blocks1, frozenCount: 2)

        let tailView1 = renderer.arrangedBlockViews[2]

        let blocks2: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("open updated")]),
        ]
        renderer.update(blocks: blocks2, frozenCount: 2)

        let tailView2 = renderer.arrangedBlockViews[2]
        #expect(tailView1 !== tailView2)
    }

    @Test("Table tail updates reuse the same placeholder view")
    func tableTailUpdatesReuseView() throws {
        let renderer = StreamingBlockRenderer()

        let initialTable = makeTableBlock(rowValues: [["alpha", "1"]])
        let expandedTable = makeTableBlock(rowValues: [["alpha", "1"], ["beta", "2"]])

        renderer.updateTail(block: initialTable)
        let firstTailView = try #require(renderer.arrangedBlockViews.last)

        renderer.updateTail(block: expandedTable)
        let secondTailView = try #require(renderer.arrangedBlockViews.last)

        #expect(firstTailView === secondTailView)
    }

    @Test("Matching tail block is promoted without replacing the view")
    func matchingTailPromotionKeepsView() throws {
        let renderer = StreamingBlockRenderer()
        let tailBlock: Block = .paragraph(content: [.text("mutable frontier")])

        renderer.updateTail(block: tailBlock)
        let previewView = try #require(renderer.arrangedBlockViews.last)

        let promoted = renderer.promoteTailIfMatching(tailBlock)
        #expect(promoted === previewView)
        #expect(renderer.arrangedBlockViews.count == 1)
        #expect(renderer.arrangedBlockViews[0] === previewView)

        _ = renderer.append(blocks: [.codeBlock(language: nil, code: "let x = 1\n")])

        #expect(renderer.arrangedBlockViews.count == 2)
        #expect(renderer.arrangedBlockViews[0] === previewView)
        #expect(renderer.arrangedBlockViews[1] is CodeBlockView)
    }

    @Test("Compatible flow tail block can be promoted without exact equality")
    func compatibleTailPromotionKeepsView() throws {
        let renderer = StreamingBlockRenderer()
        let previewBlock: Block = .paragraph(content: [.text("mutable frontier preview text")])
        let frozenBlock: Block = .paragraph(content: [.text("mutable frontier preview text with closing context")])

        renderer.updateTail(block: previewBlock)
        let previewView = try #require(renderer.arrangedBlockViews.last)

        let promoted = renderer.promoteTailIfMatching(frozenBlock)
        #expect(promoted === previewView)
        #expect(renderer.arrangedBlockViews.count == 1)
        #expect(renderer.arrangedBlockViews[0] === previewView)
    }

    @Test("Reset clears all views and state")
    func resetClearsAll() {
        let renderer = StreamingBlockRenderer()

        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .codeBlock(language: nil, code: "code\n"),
        ]
        renderer.update(blocks: blocks, frozenCount: 2)
        #expect(renderer.arrangedBlockViews.count == 2)

        renderer.reset()
        #expect(renderer.arrangedBlockViews.isEmpty)
    }

    @Test("Reset allows fresh start")
    func resetAllowsFreshStart() {
        let renderer = StreamingBlockRenderer()

        let blocks1: [Block] = [.paragraph(content: [.text("Old")])]
        renderer.update(blocks: blocks1, frozenCount: 1)

        renderer.reset()

        let blocks2: [Block] = [.paragraph(content: [.text("New")])]
        renderer.update(blocks: blocks2, frozenCount: 0)

        #expect(renderer.arrangedBlockViews.count == 1)
    }

    @Test("Structural blocks get 12pt custom spacing")
    func structuralBlocksGetCustomSpacing() {
        let renderer = StreamingBlockRenderer()

        let blocks: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("After")]),
        ]
        renderer.update(blocks: blocks, frozenCount: 3)

        let codeView = renderer.stackView.arrangedSubviews[1]
        #expect(renderer.stackView.customSpacing(after: codeView) == 12)
    }

    @Test("Multiple flow blocks group into single view")
    func multipleFlowBlocksGroupIntoSingleView() {
        let renderer = StreamingBlockRenderer()

        let blocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .paragraph(content: [.text("B")]),
            .paragraph(content: [.text("C")]),
        ]
        renderer.update(blocks: blocks, frozenCount: 3)

        #expect(renderer.arrangedBlockViews.count == 1)
        #expect(renderer.arrangedBlockViews[0] is TextFlowView)
    }

    @Test("Growing frozen count promotes views")
    func growingFrozenCountPromotesViews() {
        let renderer = StreamingBlockRenderer()

        let blocks1: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
        ]
        renderer.update(blocks: blocks1, frozenCount: 0)

        let blocks2: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
        ]
        renderer.update(blocks: blocks2, frozenCount: 1)
        let flowView = renderer.arrangedBlockViews[0]

        let blocks3: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("B")]),
        ]
        renderer.update(blocks: blocks3, frozenCount: 2)

        #expect(renderer.arrangedBlockViews.count == 3)
        #expect(renderer.arrangedBlockViews[0] === flowView)
    }

    @Test("Mixed reducer snapshots grow renderer and keep non-empty flow")
    func mixedReducerSnapshotsGrowRenderer() {
        let renderer = StreamingBlockRenderer()
        var state = BlockReducer.ReducerState()

        let events: [ParserEvent] = [
            .startHeading(level: 1), .text("Mixed"), .endHeading,
            .startParagraph, .text("Intro"), .endParagraph,
            .startList(ordered: false),
            .startListItem, .startParagraph, .text("one"), .endParagraph, .endListItem,
            .endList,
            .startCodeBlock(language: "swift"),
            .codeBlockText("let x = 1\n"),
            .endCodeBlock,
            .startParagraph, .text("Tail"), .endParagraph,
        ]

        var maxViewCount = 0
        var sawCodeBlockView = false

        for event in events {
            BlockReducer.apply(event, to: &state)
            renderer.update(blocks: state.blocks, frozenCount: state.frozenCount)

            maxViewCount = max(maxViewCount, renderer.arrangedBlockViews.count)
            if renderer.arrangedBlockViews.contains(where: { $0 is CodeBlockView }) {
                sawCodeBlockView = true
            }
        }

        #expect(maxViewCount >= 2)
        #expect(sawCodeBlockView)

        guard let flow = renderer.arrangedBlockViews.first(where: { $0 is TextFlowView }) as? TextFlowView else {
            Issue.record("Expected at least one TextFlowView in mixed snapshots")
            return
        }

        flow.frame = CGRect(x: 0, y: 0, width: 320, height: 0)
        flow.layoutIfNeeded()
        #expect(flow.intrinsicContentSize.height > 0)
    }
}

// MARK: - Container Backend Parity Tests

@MainActor
@Suite("StreamingBlockRenderer container backend parity")
struct StreamingRendererParityTests {
    @Test("Single paragraph creates one TextFlowView with container backend")
    func singleParagraphContainerBackend() {
        let renderer = StreamingBlockRenderer(backend: .containerView)
        let blocks: [Block] = [.paragraph(content: [.text("Hello")])]

        renderer.update(blocks: blocks, frozenCount: 1)

        #expect(renderer.arrangedBlockViews.count == 1)
        #expect(renderer.arrangedBlockViews[0] is TextFlowView)
    }

    @Test("Frozen views survive tail add with container backend")
    func frozenViewsSurviveContainerBackend() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks1: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]
        renderer.update(blocks: blocks1, frozenCount: 2)

        let frozenFlow = renderer.arrangedBlockViews[0]
        let frozenCode = renderer.arrangedBlockViews[1]

        let blocks2: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("After")]),
        ]
        renderer.update(blocks: blocks2, frozenCount: 2)

        #expect(renderer.arrangedBlockViews.count == 3)
        #expect(renderer.arrangedBlockViews[0] === frozenFlow)
        #expect(renderer.arrangedBlockViews[1] === frozenCode)
        #expect(renderer.arrangedBlockViews[2] is TextFlowView)
    }

    @Test("Reset clears all with container backend")
    func resetClearsAllContainerBackend() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .codeBlock(language: nil, code: "code\n"),
        ]
        renderer.update(blocks: blocks, frozenCount: 2)
        #expect(renderer.arrangedBlockViews.count == 2)

        renderer.reset()
        #expect(renderer.arrangedBlockViews.isEmpty)
        #expect(renderer.stateRegistry.isEmpty)
    }

    @Test("View types match between backends for mixed content")
    func viewTypesMatchBetweenBackends() {
        let blocks: [Block] = [
            .paragraph(content: [.text("Intro")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("Mid")]),
            .codeBlock(language: nil, code: "y\n"),
            .paragraph(content: [.text("End")]),
        ]

        let stackRenderer = StreamingBlockRenderer(backend: .stackView)
        stackRenderer.update(blocks: blocks, frozenCount: 5)

        let containerRenderer = StreamingBlockRenderer(backend: .containerView)
        containerRenderer.update(blocks: blocks, frozenCount: 5)

        let stackViews = stackRenderer.arrangedBlockViews
        let containerViews = containerRenderer.arrangedBlockViews

        #expect(stackViews.count == containerViews.count)

        for (index, stackView) in stackViews.enumerated() {
            #expect(type(of: stackView) == type(of: containerViews[index]))
        }
    }
}

// MARK: - Container Backend Tail Integration Tests

@MainActor
@Suite("StreamingBlockRenderer container backend tail")
struct StreamingRendererContainerTailTests {
    @Test("Tail update with containerView backend")
    func tailUpdateContainerBackend() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
        ]
        renderer.update(blocks: blocks, frozenCount: 5)

        let countBefore = renderer.arrangedBlockViews.count

        let tailBlock: Block = .paragraph(content: [.text("tail content")])
        renderer.updateTail(block: tailBlock)

        #expect(renderer.arrangedBlockViews.count == countBefore + 1)
        #expect(renderer.arrangedBlockViews.last is TextFlowView)
    }

    @Test("Clear tail with containerView backend")
    func clearTailContainerBackend() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
        ]
        renderer.update(blocks: blocks, frozenCount: 2)

        renderer.updateTail(block: .paragraph(content: [.text("tail")]))
        #expect(renderer.arrangedBlockViews.count == 3)

        renderer.clearTail()
        #expect(renderer.arrangedBlockViews.count == 2)
    }

    @Test("Tail promotion with containerView backend")
    func tailPromotionContainerBackend() throws {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let tailBlock: Block = .paragraph(content: [.text("mutable frontier")])
        renderer.updateTail(block: tailBlock)
        let tailView = try #require(renderer.arrangedBlockViews.last)

        let promoted = renderer.promoteTailIfMatching(tailBlock)

        #expect(promoted === tailView)
        #expect(renderer.arrangedBlockViews.count == 1)
        #expect(renderer.arrangedBlockViews[0] === tailView)
    }

    @Test("Frozen prefix identity through full pipeline with containerView backend")
    func frozenPrefixIdentityContainerBackend() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks1: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
        ]
        renderer.update(blocks: blocks1, frozenCount: 3)

        let frozenView0 = renderer.arrangedBlockViews[0]
        let frozenView1 = renderer.arrangedBlockViews[1]
        let frozenView2 = renderer.arrangedBlockViews[2]

        let blocks2: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: nil, code: "New tail 1\n"),
            .paragraph(content: [.text("New tail 2")]),
        ]
        renderer.update(blocks: blocks2, frozenCount: 3)

        #expect(renderer.arrangedBlockViews[0] === frozenView0)
        #expect(renderer.arrangedBlockViews[1] === frozenView1)
        #expect(renderer.arrangedBlockViews[2] === frozenView2)
    }
}

private extension UIView {
    func subviews<T: UIView>(ofType type: T.Type) -> [T] {
        subviews.compactMap { $0 as? T }
    }
}

private extension StreamingRendererTests {
    func makeTableBlock(rowValues: [[String]]) -> Block {
        let header = Block.TableRow(cells: [
            .init(content: [.text("name")]),
            .init(content: [.text("value")]),
        ])

        let rows = rowValues.map { row in
            Block.TableRow(cells: row.map { cell in
                .init(content: [.text(cell)])
            })
        }

        return .table(columnAlignments: [nil, nil], header: header, rows: rows)
    }
}
