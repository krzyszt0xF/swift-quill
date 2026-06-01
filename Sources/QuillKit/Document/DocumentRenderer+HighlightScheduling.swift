import QuillCore
import UIKit

extension DocumentRenderer {
    func scheduleHighlightsForNewlyFrozenCodeBlocks(
        blocks: [BlockNode],
        previousFrozenCount: Int,
        newFrozenCount: Int
    ) {
        guard newFrozenCount > previousFrozenCount else { return }

        let userInterfaceStyle = textView.traitCollection.userInterfaceStyle

        for index in previousFrozenCount..<min(newFrozenCount, blocks.count) {
            for codeBlock in makeHighlightedCodeBlocks(from: blocks[index]) {
                highlightCoordinator.scheduleHighlight(
                    blockID: codeBlock.blockID,
                    code: codeBlock.code,
                    language: codeBlock.language,
                    userInterfaceStyle: userInterfaceStyle
                )
            }
        }
    }

    func makeHighlightedCodeBlocks(from node: BlockNode) -> [HighlightableCodeBlock] {
        switch node.block {
        case let .blockquote(children):
            return children.flatMap(makeHighlightedCodeBlocks)
        case let .codeBlock(language, code):
            guard let language, !language.isEmpty else { return [] }
            return [HighlightableCodeBlock(
                blockID: node.id,
                code: code,
                language: language
            )]
        case let .orderedList(_, items):
            return items.flatMap { item in
                item.children.flatMap(makeHighlightedCodeBlocks)
            }
        case let .unorderedList(items):
            return items.flatMap { item in
                item.children.flatMap(makeHighlightedCodeBlocks)
            }
        default:
            return []
        }
    }
}
