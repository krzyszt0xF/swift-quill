import Foundation
import QuillCore

struct DocumentBlockIndexer {
    private(set) var blockSpans: [BlockSpan] = []

    var isEmpty: Bool {
        blockSpans.isEmpty
    }

    func blockSpan(for blockID: BlockIdentity) -> BlockSpan? {
        blockSpans.first { $0.blockID == blockID }
    }

    mutating func rebuild(
        from fragments: [AttributedStringBuilder.DocumentFragment],
        preservingPrefixCount prefixCount: Int
    ) {
        let preservedPrefixCount = Swift.min(prefixCount, Swift.min(blockSpans.count, fragments.count))
        var updatedSpans = Array(blockSpans.prefix(preservedPrefixCount))
        var offset = updatedSpans.last.map { $0.range.location + $0.range.length } ?? 0

        for index in preservedPrefixCount..<fragments.count {
            let fragment = fragments[index]
            let separatorLength = index > 0 ? 1 : 0
            let location = offset + separatorLength
            let range = NSRange(location: location, length: fragment.attributedString.length)

            updatedSpans.append(BlockSpan(blockID: fragment.blockID, range: range))
            offset = location + range.length
        }

        blockSpans = updatedSpans
    }

    mutating func removeAll() {
        blockSpans.removeAll()
    }

    func tailRange(after prefixCount: Int, documentLength: Int) -> NSRange? {
        guard prefixCount < blockSpans.count else { return nil }

        let tailStart = blockSpans[prefixCount].range.location
        let length = documentLength - tailStart
        guard length > 0 else { return nil }

        return NSRange(location: tailStart, length: length)
    }
}

extension DocumentBlockIndexer {
    struct BlockSpan: Equatable {
        let blockID: BlockIdentity
        let range: NSRange
    }
}
