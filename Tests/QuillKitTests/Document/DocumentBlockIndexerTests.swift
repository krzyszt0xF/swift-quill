@testable import QuillKit
import QuillCore
import Foundation
import Testing

@Suite("DocumentBlockIndexer")
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
                makeFragment("Alpha", blockID: 0),
                makeFragment("Beta", blockID: 1),
                makeFragment("Gamma", blockID: 2),
            ],
            preservingPrefixCount: 0
        )

        #expect(indexer.blockSpans.count == 3)
        #expect(indexer.blockSpans[0].blockID == BlockIdentity(rawValue: 0))
        #expect(indexer.blockSpans[1].blockID == BlockIdentity(rawValue: 1))
        #expect(indexer.blockSpans[2].blockID == BlockIdentity(rawValue: 2))
    }

    @Test("Rebuild replaces only tail after preserved prefix")
    func tailReplacement() {
        var indexer = DocumentBlockIndexer()

        indexer.rebuild(
            from: [
                makeFragment("Alpha", blockID: 0),
                makeFragment("Beta", blockID: 1),
                makeFragment("Gamma", blockID: 2),
            ],
            preservingPrefixCount: 0
        )

        indexer.rebuild(
            from: [
                makeFragment("Alpha", blockID: 0),
                makeFragment("Beta", blockID: 1),
                makeFragment("Delta", blockID: 3),
            ],
            preservingPrefixCount: 2
        )

        #expect(indexer.blockSpans.count == 3)
        #expect(indexer.blockSpans[0].blockID == BlockIdentity(rawValue: 0))
        #expect(indexer.blockSpans[1].blockID == BlockIdentity(rawValue: 1))
        #expect(indexer.blockSpans[2].blockID == BlockIdentity(rawValue: 3))
    }

    @Test("Lookup by block ID returns matching span")
    func blockIDLookup() {
        var indexer = DocumentBlockIndexer()
        let spanA = DocumentBlockIndexer.BlockSpan(
            blockID: BlockIdentity(rawValue: 0),
            range: NSRange(location: 0, length: 5)
        )
        let spanB = DocumentBlockIndexer.BlockSpan(
            blockID: BlockIdentity(rawValue: 1),
            range: NSRange(location: 6, length: 4)
        )

        indexer.rebuild(
            from: [
                makeFragment("Alpha", blockID: 0),
                makeFragment("Beta", blockID: 1),
            ],
            preservingPrefixCount: 0
        )

        #expect(indexer.blockSpan(for: BlockIdentity(rawValue: 0)) == spanA)
        #expect(indexer.blockSpan(for: BlockIdentity(rawValue: 1)) == spanB)
        #expect(indexer.blockSpan(for: BlockIdentity(rawValue: 99)) == nil)
    }

    @Test("Tail range returns contiguous range after preserved prefix")
    func contiguousTailRange() {
        var indexer = DocumentBlockIndexer()

        indexer.rebuild(
            from: [
                makeFragment("Alpha", blockID: 0),
                makeFragment("Beta", blockID: 1),
                makeFragment("Gamma", blockID: 2),
                makeFragment("Delta", blockID: 3),
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
                makeFragment("Alpha", blockID: 0),
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
                makeFragment("Alpha", blockID: 0),
                makeFragment("Beta", blockID: 1),
            ],
            preservingPrefixCount: 0
        )

        indexer.removeAll()

        #expect(indexer.blockSpans.isEmpty)
        #expect(indexer.isEmpty)
    }
}

private extension DocumentBlockIndexerTests {
    func makeFragment(_ text: String, blockID: UInt64) -> AttributedStringBuilder.DocumentFragment {
        AttributedStringBuilder.DocumentFragment(
            attributedString: NSAttributedString(string: text),
            blockID: BlockIdentity(rawValue: blockID)
        )
    }
}
