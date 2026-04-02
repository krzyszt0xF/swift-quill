@testable import QuillKit
import QuillCore
import Foundation
import QuillSharedTestSupport
import Testing

@Suite("DocumentBlockIndexer", .tags(.rendering))
struct DocumentBlockIndexerTests {
    @Test("Empty indexer has no block spans")
    func emptyIndexer() {
        let indexer = DocumentBlockIndexer()

        #expect(indexer.blockSpans.isEmpty)
        #expect(indexer.isEmpty)
        #expect(indexer.tailRange(after: 0, documentLength: 0) == nil)
    }

    @Test("Rebuild preserves insertion order")
    func orderedRebuild() {
        var indexer = DocumentBlockIndexer()

        indexer.rebuild(
            from: [
                makeFragment("Alpha", ownerBlockID: 0),
                makeFragment("Beta", ownerBlockID: 1),
                makeFragment("Gamma", ownerBlockID: 2),
            ],
            preservingPrefixCount: 0
        )

        #expect(indexer.blockSpans.count == 3)
        #expect(indexer.blockSpans[0].ownerBlockID == BlockIdentity(rawValue: 0))
        #expect(indexer.blockSpans[1].ownerBlockID == BlockIdentity(rawValue: 1))
        #expect(indexer.blockSpans[2].ownerBlockID == BlockIdentity(rawValue: 2))
    }

    @Test("Rebuild replaces only tail after preserved prefix")
    func tailReplacement() {
        var indexer = DocumentBlockIndexer()

        indexer.rebuild(
            from: [
                makeFragment("Alpha", ownerBlockID: 0),
                makeFragment("Beta", ownerBlockID: 1),
                makeFragment("Gamma", ownerBlockID: 2),
            ],
            preservingPrefixCount: 0
        )

        indexer.rebuild(
            from: [
                makeFragment("Alpha", ownerBlockID: 0),
                makeFragment("Beta", ownerBlockID: 1),
                makeFragment("Delta", ownerBlockID: 3),
            ],
            preservingPrefixCount: 2
        )

        #expect(indexer.blockSpans.count == 3)
        #expect(indexer.blockSpans[0].ownerBlockID == BlockIdentity(rawValue: 0))
        #expect(indexer.blockSpans[1].ownerBlockID == BlockIdentity(rawValue: 1))
        #expect(indexer.blockSpans[2].ownerBlockID == BlockIdentity(rawValue: 3))
    }

    @Test("Lookup by block ID returns matching span")
    func blockIDLookup() {
        var indexer = DocumentBlockIndexer()
        let spanA = DocumentBlockIndexer.BlockSpan(
            ownerBlockID: BlockIdentity(rawValue: 0),
            range: NSRange(location: 0, length: 5)
        )
        let spanB = DocumentBlockIndexer.BlockSpan(
            ownerBlockID: BlockIdentity(rawValue: 1),
            range: NSRange(location: 6, length: 4)
        )

        indexer.rebuild(
            from: [
                makeFragment("Alpha", ownerBlockID: 0),
                makeFragment("Beta", ownerBlockID: 1),
            ],
            preservingPrefixCount: 0
        )

        #expect(indexer.blockSpan(for: BlockIdentity(rawValue: 0)) == spanA)
        #expect(indexer.blockSpan(for: BlockIdentity(rawValue: 1)) == spanB)
        #expect(indexer.blockSpan(for: BlockIdentity(rawValue: 99)) == nil)
    }

    @Test("Multiple render fragments with same owner form one block span")
    func groupedOwnerFragments() {
        var indexer = DocumentBlockIndexer()

        indexer.rebuild(
            from: [
                makeFragment("1.\tItem", ownerBlockID: 0, contentBlockID: 1),
                makeFragment("print(\"Hi\")", ownerBlockID: 0, contentBlockID: 2),
                makeFragment("Next", ownerBlockID: 3, contentBlockID: 4),
            ],
            preservingPrefixCount: 0
        )

        #expect(indexer.blockSpans.count == 2)
        #expect(indexer.blockSpans[0].ownerBlockID == BlockIdentity(rawValue: 0))
        #expect(indexer.blockSpans[0].range == NSRange(location: 0, length: 19))
        #expect(indexer.blockSpans[1].ownerBlockID == BlockIdentity(rawValue: 3))
        #expect(indexer.blockSpans[1].range == NSRange(location: 20, length: 4))
    }

    @Test("Tail range returns contiguous range after preserved prefix")
    func contiguousTailRange() {
        var indexer = DocumentBlockIndexer()

        indexer.rebuild(
            from: [
                makeFragment("Alpha", ownerBlockID: 0),
                makeFragment("Beta", ownerBlockID: 1),
                makeFragment("Gamma", ownerBlockID: 2),
                makeFragment("Delta", ownerBlockID: 3),
            ],
            preservingPrefixCount: 0
        )

        let documentLength = "Alpha\nBeta\nGamma\nDelta".count
        let tail = indexer.tailRange(after: 2, documentLength: documentLength)

        #expect(tail == NSRange(location: 11, length: 11))
    }

    @Test("Tail range with no tail block spans returns nil")
    func tailRangeWithoutTail() {
        var indexer = DocumentBlockIndexer()

        indexer.rebuild(
            from: [
                makeFragment("Alpha", ownerBlockID: 0),
            ],
            preservingPrefixCount: 0
        )

        #expect(indexer.tailRange(after: 1, documentLength: 5) == nil)
    }

    @Test("Remove all clears block spans")
    func removeAll() {
        var indexer = DocumentBlockIndexer()

        indexer.rebuild(
            from: [
                makeFragment("Alpha", ownerBlockID: 0),
                makeFragment("Beta", ownerBlockID: 1),
            ],
            preservingPrefixCount: 0
        )

        indexer.removeAll()

        #expect(indexer.blockSpans.isEmpty)
        #expect(indexer.isEmpty)
    }
}

private extension DocumentBlockIndexerTests {
    func makeFragment(
        _ text: String,
        ownerBlockID: UInt64,
        contentBlockID: UInt64? = nil
    ) -> RenderFragment {
        RenderFragment(
            attributedString: NSAttributedString(string: text),
            contentBlockID: BlockIdentity(rawValue: contentBlockID ?? ownerBlockID),
            ownerBlockID: BlockIdentity(rawValue: ownerBlockID),
            presentationRole: .regularBlock
        )
    }
}
