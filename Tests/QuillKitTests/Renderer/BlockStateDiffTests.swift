@testable import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("BlockState diff pipeline")
struct BlockStateDiffTests {
    @Test("Distinct structural siblings receive distinct state IDs")
    func distinctStructuralSiblingsReceiveDistinctStateIDs() {
        let renderer = StreamingBlockRenderer()

        let blocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "B\n"),
            .codeBlock(language: "swift", code: "C\n"),
        ]
        renderer.update(blocks: blocks, frozenCount: 3)

        #expect(renderer.stateRegistry.count == 3)

        let firstStateID = renderer.stateRegistry[0].id
        let secondStateID = renderer.stateRegistry[1].id
        let thirdStateID = renderer.stateRegistry[2].id

        #expect(renderer.renderedBlockViews[0] is TextFlowView)
        #expect(renderer.renderedBlockViews[1] is CodeBlockView)
        #expect(renderer.renderedBlockViews[2] is CodeBlockView)
        #expect(firstStateID != secondStateID)
        #expect(secondStateID != thirdStateID)
        #expect(firstStateID != thirdStateID)
    }

    @Test("Fresh IDs after reset")
    func freshIDsAppearAfterReset() {
        let renderer = StreamingBlockRenderer()

        let blocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "B\n"),
        ]
        renderer.update(blocks: blocks, frozenCount: 2)

        let oldStateIDs = renderer.stateRegistry.map(\.id)
        #expect(oldStateIDs.count == 2)

        renderer.reset()
        #expect(renderer.stateRegistry.isEmpty)

        renderer.update(blocks: blocks, frozenCount: 2)

        let newStateIDs = renderer.stateRegistry.map(\.id)
        #expect(newStateIDs.count == 2)
        #expect(newStateIDs[0] != oldStateIDs[0])
        #expect(newStateIDs[1] != oldStateIDs[1])
    }

    @Test("Frozen prefix immutability: no operations target frozen indices on tail update")
    func frozenPrefixRemainsImmutableDuringTailUpdate() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 5)

        let frozenViews = renderer.renderedBlockViews.map { $0 }
        let frozenStateIDs = renderer.stateRegistry.prefix(5).map(\.id)

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
            .codeBlock(language: nil, code: "Tail\n"),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 5)

        for index in 0..<5 {
            #expect(renderer.stateRegistry[index].id == frozenStateIDs[index])
            #expect(renderer.renderedBlockViews[index] === frozenViews[index])
        }
    }

    @Test("Insert detection appends new block at end")
    func insertDetectionAppendsNewBlockAtEnd() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .paragraph(content: [.text("B")]),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 2)
        #expect(renderer.renderedBlockViews.count == 1)

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .paragraph(content: [.text("B")]),
            .codeBlock(language: nil, code: "C\n"),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 2)

        #expect(renderer.renderedBlockViews.count == 2)
        #expect(renderer.stateRegistry.count == 2)
    }

    @Test("Mixed operations: grow from three to four blocks")
    func mixedOperationsPreserveFrozenStateIDs() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("P1")]),
            .codeBlock(language: nil, code: "code\n"),
            .paragraph(content: [.text("P2")]),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 3)

        let frozenStateIDs = renderer.stateRegistry.map(\.id)

        let expandedBlocks: [Block] = [
            .paragraph(content: [.text("P1")]),
            .codeBlock(language: nil, code: "code\n"),
            .paragraph(content: [.text("P2")]),
            .paragraph(content: [.text("P3")]),
        ]
        renderer.update(blocks: expandedBlocks, frozenCount: 3)

        #expect(renderer.stateRegistry[0].id == frozenStateIDs[0])
        #expect(renderer.stateRegistry[1].id == frozenStateIDs[1])
        #expect(renderer.stateRegistry[2].id == frozenStateIDs[2])
        #expect(renderer.stateRegistry.count >= 3)
    }

    @Test("Remove detection drops block when frozen count increases past it")
    func removeDetectionDropsBlockWhenItDisappears() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "B\n"),
            .paragraph(content: [.text("C")]),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 2)

        #expect(renderer.renderedBlockViews.count == 3)
        let initialRegistryCount = renderer.stateRegistry.count

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "B\n"),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 2)

        #expect(renderer.stateRegistry.count == 2)
        #expect(renderer.stateRegistry.count < initialRegistryCount)
    }

    @Test("Stable IDs persist for frozen blocks across updates")
    func stableIDsPersistForFrozenBlocksAcrossUpdates() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 2)

        let frozenStateIDs = renderer.stateRegistry.map(\.id)
        #expect(frozenStateIDs.count == 2)

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("B")]),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 2)

        #expect(renderer.stateRegistry.count == 3)
        #expect(renderer.stateRegistry[0].id == frozenStateIDs[0])
        #expect(renderer.stateRegistry[1].id == frozenStateIDs[1])
        #expect(renderer.stateRegistry[2].id != frozenStateIDs[0])
        #expect(renderer.stateRegistry[2].id != frozenStateIDs[1])
    }

    @Test("Update detection replaces content for same ID")
    func updateDetectionReplacesContentForSameID() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "old\n"),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 2)

        let codeBlockStateID = renderer.stateRegistry[1].id

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "updated\n"),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 2)

        #expect(renderer.stateRegistry[1].id == codeBlockStateID)
        #expect(renderer.stateRegistry[1].node == .codeBlock(language: nil, code: "updated\n"))
    }
}
