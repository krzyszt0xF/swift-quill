@testable import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("StreamingBlockRenderer Tail")
struct StreamingRendererTailTests {
    @Test("Clear tail removes the tail view")
    func clearTailRemovesTailView() {
        let renderer = StreamingBlockRenderer()

        let frozenBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
        ]
        renderer.update(blocks: frozenBlocks, frozenCount: 2)

        renderer.updateTail(block: .paragraph(content: [.text("tail")]))
        #expect(renderer.renderedBlockViews.count == 3)

        renderer.clearTail()
        #expect(renderer.renderedBlockViews.count == 2)
    }

    @Test("Frozen prefix identity through full pipeline")
    func frozenPrefixRemainsStableAcrossTailChanges() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 3)

        let firstFrozenView = renderer.renderedBlockViews[0]
        let secondFrozenView = renderer.renderedBlockViews[1]
        let thirdFrozenView = renderer.renderedBlockViews[2]

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: nil, code: "New tail 1\n"),
            .paragraph(content: [.text("New tail 2")]),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 3)

        #expect(renderer.renderedBlockViews[0] === firstFrozenView)
        #expect(renderer.renderedBlockViews[1] === secondFrozenView)
        #expect(renderer.renderedBlockViews[2] === thirdFrozenView)
    }

    @Test("Tail promotion keeps the same view instance")
    func tailPromotionKeepsViewIdentity() throws {
        let renderer = StreamingBlockRenderer()

        let tailBlock: Block = .paragraph(content: [.text("mutable frontier")])
        renderer.updateTail(block: tailBlock)
        let tailView = try #require(renderer.renderedBlockViews.last)

        let promotedView = renderer.promoteTailIfMatching(tailBlock)

        #expect(promotedView === tailView)
        #expect(renderer.renderedBlockViews.count == 1)
        #expect(renderer.renderedBlockViews[0] === tailView)
    }

    @Test("Tail update adds view after frozen content")
    func tailUpdateAddsViewAfterFrozenContent() {
        let renderer = StreamingBlockRenderer()

        let frozenBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
        ]
        renderer.update(blocks: frozenBlocks, frozenCount: 5)

        let renderedViewCountBeforeTail = renderer.renderedBlockViews.count

        let tailBlock: Block = .paragraph(content: [.text("tail content")])
        renderer.updateTail(block: tailBlock)

        #expect(renderer.renderedBlockViews.count == renderedViewCountBeforeTail + 1)
        #expect(renderer.renderedBlockViews.last is TextFlowView)
    }
}
