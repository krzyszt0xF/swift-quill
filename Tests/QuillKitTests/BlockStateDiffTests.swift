@testable import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("BlockState diff pipeline")
struct BlockStateDiffTests {
    @Test("Stable IDs persist for frozen blocks across updates")
    func stableIDPersistence() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks1: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]
        renderer.update(blocks: blocks1, frozenCount: 2)

        let frozenIDs = renderer.stateRegistry.map(\.id)
        #expect(frozenIDs.count == 2)

        let blocks2: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("B")]),
        ]
        renderer.update(blocks: blocks2, frozenCount: 2)

        #expect(renderer.stateRegistry.count == 3)
        #expect(renderer.stateRegistry[0].id == frozenIDs[0])
        #expect(renderer.stateRegistry[1].id == frozenIDs[1])
        #expect(renderer.stateRegistry[2].id != frozenIDs[0])
        #expect(renderer.stateRegistry[2].id != frozenIDs[1])
    }

    @Test("Insert detection appends new block at end")
    func insertDetection() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks1: [Block] = [
            .paragraph(content: [.text("A")]),
            .paragraph(content: [.text("B")]),
        ]
        renderer.update(blocks: blocks1, frozenCount: 2)
        #expect(renderer.arrangedBlockViews.count == 1)

        let blocks2: [Block] = [
            .paragraph(content: [.text("A")]),
            .paragraph(content: [.text("B")]),
            .codeBlock(language: nil, code: "C\n"),
        ]
        renderer.update(blocks: blocks2, frozenCount: 2)

        #expect(renderer.arrangedBlockViews.count == 2)
        #expect(renderer.stateRegistry.count == 2)
    }

    @Test("Remove detection drops block when frozen count increases past it")
    func removeDetection() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks1: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "B\n"),
            .paragraph(content: [.text("C")]),
        ]
        renderer.update(blocks: blocks1, frozenCount: 2)

        #expect(renderer.arrangedBlockViews.count == 3)
        let initialCount = renderer.stateRegistry.count

        let blocks2: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "B\n"),
        ]
        renderer.update(blocks: blocks2, frozenCount: 2)

        #expect(renderer.stateRegistry.count == 2)
        #expect(renderer.stateRegistry.count < initialCount)
    }

    @Test("Update detection replaces content for same ID")
    func updateDetection() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks1: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "old\n"),
        ]
        renderer.update(blocks: blocks1, frozenCount: 2)

        let idBefore = renderer.stateRegistry[1].id

        let blocks2: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "updated\n"),
        ]
        renderer.update(blocks: blocks2, frozenCount: 2)

        #expect(renderer.stateRegistry[1].id == idBefore)
        #expect(renderer.stateRegistry[1].node == .codeBlock(language: nil, code: "updated\n"))
    }

    @Test("Mixed operations: grow from three to four blocks")
    func mixedOperations() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks1: [Block] = [
            .paragraph(content: [.text("P1")]),
            .codeBlock(language: nil, code: "code\n"),
            .paragraph(content: [.text("P2")]),
        ]
        renderer.update(blocks: blocks1, frozenCount: 3)

        let frozenIDs = renderer.stateRegistry.map(\.id)

        let blocks2: [Block] = [
            .paragraph(content: [.text("P1")]),
            .codeBlock(language: nil, code: "code\n"),
            .paragraph(content: [.text("P2")]),
            .paragraph(content: [.text("P3")]),
        ]
        renderer.update(blocks: blocks2, frozenCount: 3)

        #expect(renderer.stateRegistry[0].id == frozenIDs[0])
        #expect(renderer.stateRegistry[1].id == frozenIDs[1])
        #expect(renderer.stateRegistry[2].id == frozenIDs[2])
        #expect(renderer.stateRegistry.count >= 3)
    }

    @Test("Move detection preserves view identity")
    func moveDetection() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks1: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "B\n"),
            .codeBlock(language: "swift", code: "C\n"),
        ]
        renderer.update(blocks: blocks1, frozenCount: 3)

        let viewA = renderer.arrangedBlockViews[0]
        let viewB = renderer.arrangedBlockViews[1]
        let viewC = renderer.arrangedBlockViews[2]

        #expect(renderer.stateRegistry.count == 3)

        let idA = renderer.stateRegistry[0].id
        let idB = renderer.stateRegistry[1].id
        let idC = renderer.stateRegistry[2].id

        #expect(viewA is TextFlowView)
        #expect(viewB is CodeBlockView)
        #expect(viewC is CodeBlockView)
        #expect(idA != idB)
        #expect(idB != idC)
    }

    @Test("Frozen prefix immutability: no operations target frozen indices on tail update")
    func frozenPrefixImmutability() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks1: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
        ]
        renderer.update(blocks: blocks1, frozenCount: 5)

        let frozenViews = renderer.arrangedBlockViews.map { $0 }
        let frozenIDs = renderer.stateRegistry.prefix(5).map(\.id)

        let blocks2: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
            .codeBlock(language: nil, code: "Tail\n"),
        ]
        renderer.update(blocks: blocks2, frozenCount: 5)

        for i in 0..<5 {
            #expect(renderer.stateRegistry[i].id == frozenIDs[i])
            #expect(renderer.arrangedBlockViews[i] === frozenViews[i])
        }
    }

    @Test("Fresh IDs after reset")
    func freshIDsAfterReset() {
        let renderer = StreamingBlockRenderer(backend: .containerView)

        let blocks: [Block] = [
            .paragraph(content: [.text("A")]),
            .codeBlock(language: nil, code: "B\n"),
        ]
        renderer.update(blocks: blocks, frozenCount: 2)

        let oldIDs = renderer.stateRegistry.map(\.id)
        #expect(oldIDs.count == 2)

        renderer.reset()
        #expect(renderer.stateRegistry.isEmpty)

        renderer.update(blocks: blocks, frozenCount: 2)

        let newIDs = renderer.stateRegistry.map(\.id)
        #expect(newIDs.count == 2)
        #expect(newIDs[0] != oldIDs[0])
        #expect(newIDs[1] != oldIDs[1])
    }
}
