import QuillCore

extension DocumentRenderer {
    func scheduleImageLoadsForNewlyFrozenBlocks(
        blocks: [BlockNode],
        previousFrozenCount: Int,
        newFrozenCount: Int
    ) {
        guard newFrozenCount > previousFrozenCount else { return }

        for index in previousFrozenCount..<min(newFrozenCount, blocks.count) {
            for image in makeLoadableImages(from: blocks[index]) {
                imageLoadingCoordinator.scheduleLoad(
                    blockID: image.blockID,
                    source: image.source
                )
            }
        }
    }

    func makeLoadableImages(from node: BlockNode) -> [LoadableImage] {
        switch node.block {
        case let .blockquote(children):
            return children.flatMap(makeLoadableImages)
        case let .orderedList(_, items):
            return items.flatMap { item in
                item.children.flatMap(makeLoadableImages)
            }
        case let .paragraph(content):
            guard content.count == 1,
                  case let .image(source, _, _)? = content.first
            else {
                return []
            }
            return [.init(blockID: node.id, source: source)]
        case let .unorderedList(items):
            return items.flatMap { item in
                item.children.flatMap(makeLoadableImages)
            }
        default:
            return []
        }
    }
}
