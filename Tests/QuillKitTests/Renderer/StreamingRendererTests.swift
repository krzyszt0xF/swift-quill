@testable import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("StreamingBlockRenderer")
struct StreamingRendererTests {
    private static let testWidth: CGFloat = 320

    @Test("Growing frozen count promotes views")
    func growingFrozenCountPromotesViews() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 0)

        let partiallyFrozenBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
        ]
        renderer.update(blocks: partiallyFrozenBlocks, frozenCount: 1)
        let promotedFlowView = renderer.renderedBlockViews[0]

        let expandedBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("B")]),
        ]
        renderer.update(blocks: expandedBlocks, frozenCount: 2)

        #expect(renderer.renderedBlockViews.count == 3)
        #expect(renderer.renderedBlockViews[0] === promotedFlowView)
    }

    @Test("Mixed reducer snapshots grow renderer and keep non-empty flow")
    func mixedReducerSnapshotsGrowRenderer() {
        let renderer = StreamingBlockRenderer()
        var reducerState = BlockReducer.ReducerState()

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

        var maximumViewCount = 0
        var sawCodeBlockView = false

        for event in events {
            BlockReducer.apply(event, to: &reducerState)
            renderer.update(blocks: reducerState.blocks, frozenCount: reducerState.frozenCount)

            maximumViewCount = max(maximumViewCount, renderer.renderedBlockViews.count)
            if renderer.renderedBlockViews.contains(where: { $0 is CodeBlockView }) {
                sawCodeBlockView = true
            }
        }

        #expect(maximumViewCount >= 2)
        #expect(sawCodeBlockView)

        guard let flowView = renderer.renderedBlockViews.first(where: { $0 is TextFlowView }) as? TextFlowView else {
            Issue.record("Expected at least one TextFlowView in mixed snapshots")
            return
        }

        flowView.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: 0)
        flowView.layoutIfNeeded()
        #expect(flowView.intrinsicContentSize.height > 0)
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

        #expect(renderer.renderedBlockViews.count == 1)
        #expect(renderer.renderedBlockViews[0] is TextFlowView)
    }

    @Test("Paragraph then code block creates two views")
    func paragraphThenCodeBlockCreatesTwoViews() {
        let renderer = StreamingBlockRenderer()
        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]

        renderer.update(blocks: blocks, frozenCount: 2)

        #expect(renderer.renderedBlockViews.count == 2)
        #expect(renderer.renderedBlockViews[0] is TextFlowView)
        #expect(renderer.renderedBlockViews[1] is CodeBlockView)
    }

    @Test("Compatible flow tail block can be promoted without exact equality")
    func compatibleTailPromotionKeepsView() throws {
        let renderer = StreamingBlockRenderer()
        let previewBlock: Block = .paragraph(content: [.text("mutable frontier preview text")])
        let frozenBlock: Block = .paragraph(content: [.text("mutable frontier preview text with closing context")])

        renderer.updateTail(block: previewBlock)
        let previewView = try #require(renderer.renderedBlockViews.last)

        let promotedView = renderer.promoteTailIfMatching(frozenBlock)
        #expect(promotedView === previewView)
        #expect(renderer.renderedBlockViews.count == 1)
        #expect(renderer.renderedBlockViews[0] === previewView)
    }

    @Test("Reset allows fresh start")
    func resetAllowsFreshStart() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [.paragraph(content: [.text("Old")])]
        renderer.update(blocks: initialBlocks, frozenCount: 1)

        renderer.reset()

        let replacementBlocks: [Block] = [.paragraph(content: [.text("New")])]
        renderer.update(blocks: replacementBlocks, frozenCount: 0)

        #expect(renderer.renderedBlockViews.count == 1)
    }

    @Test("Reset clears all views and state")
    func resetClearsViewsAndState() {
        let renderer = StreamingBlockRenderer()

        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .codeBlock(language: nil, code: "code\n"),
        ]
        renderer.update(blocks: blocks, frozenCount: 2)
        #expect(renderer.renderedBlockViews.count == 2)

        renderer.reset()
        #expect(renderer.renderedBlockViews.isEmpty)
        #expect(renderer.stateRegistry.isEmpty)
    }

    @Test("Single paragraph creates one TextFlowView")
    func singleParagraphCreatesSingleTextFlowView() {
        let renderer = StreamingBlockRenderer()
        let blocks: [Block] = [.paragraph(content: [.text("Hello")])]

        renderer.update(blocks: blocks, frozenCount: 1)

        #expect(renderer.renderedBlockViews.count == 1)
        #expect(renderer.renderedBlockViews[0] is TextFlowView)
    }

    @Test("Matching tail block is promoted without replacing the view")
    func exactTailPromotionKeepsView() throws {
        let renderer = StreamingBlockRenderer()
        let tailBlock: Block = .paragraph(content: [.text("mutable frontier")])

        renderer.updateTail(block: tailBlock)
        let previewView = try #require(renderer.renderedBlockViews.last)

        let promotedView = renderer.promoteTailIfMatching(tailBlock)
        #expect(promotedView === previewView)
        #expect(renderer.renderedBlockViews.count == 1)
        #expect(renderer.renderedBlockViews[0] === previewView)

        _ = renderer.append(blocks: [.codeBlock(language: nil, code: "let x = 1\n")])

        #expect(renderer.renderedBlockViews.count == 2)
        #expect(renderer.renderedBlockViews[0] === previewView)
        #expect(renderer.renderedBlockViews[1] is CodeBlockView)
    }

    @Test("Table tail updates reuse the same placeholder view")
    func tableTailUpdatesReuseView() throws {
        let renderer = StreamingBlockRenderer()

        let initialTableBlock = makeTableBlock(rowValues: [["alpha", "1"]])
        let expandedTableBlock = makeTableBlock(rowValues: [["alpha", "1"], ["beta", "2"]])

        renderer.updateTail(block: initialTableBlock)
        let initialTailView = try #require(renderer.renderedBlockViews.last)

        renderer.updateTail(block: expandedTableBlock)
        let updatedTailView = try #require(renderer.renderedBlockViews.last)

        #expect(initialTailView === updatedTailView)
    }

    @Test("Tail views are rebuilt not reused")
    func tailUpdatesRebuildViews() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("open")]),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 2)

        let initialTailView = renderer.renderedBlockViews[2]

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("open updated")]),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 2)

        let updatedTailView = renderer.renderedBlockViews[2]
        #expect(initialTailView !== updatedTailView)
    }

    @Test("Frozen prefix with three structural nodes preserved across updates")
    func threeNodeFrozenPrefixPersistsAcrossUpdates() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("B")]),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 3)

        let initialFlowView = renderer.renderedBlockViews[0]
        let initialCodeView = renderer.renderedBlockViews[1]
        let trailingFlowView = renderer.renderedBlockViews[2]

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("B")]),
            .codeBlock(language: "py", code: "y\n"),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 3)

        #expect(renderer.renderedBlockViews.count == 4)
        #expect(renderer.renderedBlockViews[0] === initialFlowView)
        #expect(renderer.renderedBlockViews[1] === initialCodeView)
        #expect(renderer.renderedBlockViews[2] === trailingFlowView)
    }

    @Test("Frozen views survive when tail is added")
    func frozenViewsRemainStableWhenTailIsAdded() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 2)

        let frozenFlowView = renderer.renderedBlockViews[0]
        let frozenCodeView = renderer.renderedBlockViews[1]

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("After")]),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 2)

        #expect(renderer.renderedBlockViews.count == 3)
        #expect(renderer.renderedBlockViews[0] === frozenFlowView)
        #expect(renderer.renderedBlockViews[1] === frozenCodeView)
        #expect(renderer.renderedBlockViews[2] is TextFlowView)
    }
}

private extension StreamingRendererTests {
    func makeTableBlock(rowValues: [[String]]) -> Block {
        let header = Block.TableRow(cells: [
            .init(content: [.text("name")]),
            .init(content: [.text("value")]),
        ])

        let rows = rowValues.map { rowValues in
            Block.TableRow(cells: rowValues.map { cellValue in
                .init(content: [.text(cellValue)])
            })
        }

        return .table(columnAlignments: [nil, nil], header: header, rows: rows)
    }
}
