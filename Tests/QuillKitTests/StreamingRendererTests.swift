import QuillCore
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

        #expect(renderer.stackView.arrangedSubviews.count == 1)
        #expect(renderer.stackView.arrangedSubviews[0] is TextFlowView)
    }

    @Test("Paragraph then code block creates two views")
    func paragraphThenCodeBlock() {
        let renderer = StreamingBlockRenderer()
        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]

        renderer.update(blocks: blocks, frozenCount: 2)

        #expect(renderer.stackView.arrangedSubviews.count == 2)
        #expect(renderer.stackView.arrangedSubviews[0] is TextFlowView)
        #expect(renderer.stackView.arrangedSubviews[1] is CodeBlockView)
    }

    @Test("Frozen views survive when tail is added")
    func frozenViewsSurviveTailAdd() {
        let renderer = StreamingBlockRenderer()

        let blocks1: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]
        renderer.update(blocks: blocks1, frozenCount: 2)

        let frozenFlow = renderer.stackView.arrangedSubviews[0]
        let frozenCode = renderer.stackView.arrangedSubviews[1]

        let blocks2: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("After")]),
        ]
        renderer.update(blocks: blocks2, frozenCount: 2)

        #expect(renderer.stackView.arrangedSubviews.count == 3)
        #expect(renderer.stackView.arrangedSubviews[0] === frozenFlow)
        #expect(renderer.stackView.arrangedSubviews[1] === frozenCode)
        #expect(renderer.stackView.arrangedSubviews[2] is TextFlowView)
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

        let view0 = renderer.stackView.arrangedSubviews[0]
        let view1 = renderer.stackView.arrangedSubviews[1]
        let view2 = renderer.stackView.arrangedSubviews[2]

        let blocks2: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("B")]),
            .codeBlock(language: "py", code: "y\n"),
        ]
        renderer.update(blocks: blocks2, frozenCount: 3)

        #expect(renderer.stackView.arrangedSubviews.count == 4)
        #expect(renderer.stackView.arrangedSubviews[0] === view0)
        #expect(renderer.stackView.arrangedSubviews[1] === view1)
        #expect(renderer.stackView.arrangedSubviews[2] === view2)
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

        let tailView1 = renderer.stackView.arrangedSubviews[2]

        let blocks2: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("open updated")]),
        ]
        renderer.update(blocks: blocks2, frozenCount: 2)

        let tailView2 = renderer.stackView.arrangedSubviews[2]
        #expect(tailView1 !== tailView2)
    }

    @Test("Reset clears all views and state")
    func resetClearsAll() {
        let renderer = StreamingBlockRenderer()

        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .codeBlock(language: nil, code: "code\n"),
        ]
        renderer.update(blocks: blocks, frozenCount: 2)
        #expect(renderer.stackView.arrangedSubviews.count == 2)

        renderer.reset()
        #expect(renderer.stackView.arrangedSubviews.isEmpty)
    }

    @Test("Reset allows fresh start")
    func resetAllowsFreshStart() {
        let renderer = StreamingBlockRenderer()

        let blocks1: [Block] = [.paragraph(content: [.text("Old")])]
        renderer.update(blocks: blocks1, frozenCount: 1)

        renderer.reset()

        let blocks2: [Block] = [.paragraph(content: [.text("New")])]
        renderer.update(blocks: blocks2, frozenCount: 0)

        #expect(renderer.stackView.arrangedSubviews.count == 1)
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

        #expect(renderer.stackView.arrangedSubviews.count == 1)
        #expect(renderer.stackView.arrangedSubviews[0] is TextFlowView)
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
        let flowView = renderer.stackView.arrangedSubviews[0]

        let blocks3: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "x\n"),
            .paragraph(content: [.text("B")]),
        ]
        renderer.update(blocks: blocks3, frozenCount: 2)

        #expect(renderer.stackView.arrangedSubviews.count == 3)
        #expect(renderer.stackView.arrangedSubviews[0] === flowView)
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

            maxViewCount = max(maxViewCount, renderer.stackView.arrangedSubviews.count)
            if renderer.stackView.arrangedSubviews.contains(where: { $0 is CodeBlockView }) {
                sawCodeBlockView = true
            }
        }

        #expect(maxViewCount >= 2)
        #expect(sawCodeBlockView)

        guard let flow = renderer.stackView.arrangedSubviews.first(where: { $0 is TextFlowView }) as? TextFlowView else {
            Issue.record("Expected at least one TextFlowView in mixed snapshots")
            return
        }

        flow.frame = CGRect(x: 0, y: 0, width: 320, height: 0)
        flow.layoutIfNeeded()
        #expect(flow.intrinsicContentSize.height > 0)
    }
}
