import Foundation
import QuillCore

struct DocumentBlockIndexer {
    private(set) var blockSpans: [BlockSpan] = []

    var isEmpty: Bool {
        blockSpans.isEmpty
    }

    func blockSpan(for ownerBlockID: BlockIdentity) -> BlockSpan? {
        blockSpans.first { $0.ownerBlockID == ownerBlockID }
    }

    mutating func rebuild(
        from fragments: [RenderFragment],
        preservingPrefixCount prefixCount: Int
    ) {
        let ownerGroups = makeOwnerGroups(from: fragments)
        let preservedPrefixCount = Swift.min(prefixCount, Swift.min(blockSpans.count, ownerGroups.count))
        var updatedSpans = Array(blockSpans.prefix(preservedPrefixCount))
        var offset = updatedSpans.last.map { $0.range.location + $0.range.length } ?? 0

        for index in preservedPrefixCount..<ownerGroups.count {
            let group = ownerGroups[index]
            let separatorLength = updatedSpans.isEmpty ? 0 : 1
            let location = offset + separatorLength
            let range = NSRange(location: location, length: group.length)

            updatedSpans.append(BlockSpan(ownerBlockID: group.ownerBlockID, range: range))
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
        let ownerBlockID: BlockIdentity
        let range: NSRange
    }
}

private extension DocumentBlockIndexer {
    struct OwnerGroup {
        let length: Int
        let ownerBlockID: BlockIdentity
    }

    func makeOwnerGroups(from fragments: [RenderFragment]) -> [OwnerGroup] {
        var groups: [OwnerGroup] = []

        for fragment in fragments {
            if let lastIndex = groups.indices.last,
               groups[lastIndex].ownerBlockID == fragment.ownerBlockID {
                groups[lastIndex] = OwnerGroup(
                    length: groups[lastIndex].length + 1 + fragment.attributedString.length,
                    ownerBlockID: groups[lastIndex].ownerBlockID
                )
                continue
            }

            groups.append(OwnerGroup(
                length: fragment.attributedString.length,
                ownerBlockID: fragment.ownerBlockID
            ))
        }

        return groups
    }
}
