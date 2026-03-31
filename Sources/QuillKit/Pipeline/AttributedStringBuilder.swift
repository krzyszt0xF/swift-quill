import QuillCore
import UIKit

enum AttributedStringBuilder {
    static func build(from blocks: [Block]) -> NSAttributedString {
        BlockAttributedStringRenderer.build(from: blocks)
    }

    static func buildDocument(
        from fragments: [RenderFragment]
    ) -> NSAttributedString {
        RenderDocumentAssembler.buildDocument(from: fragments)
    }

    static func buildRenderFragments(
        from nodes: [BlockNode],
        frozenCount: Int,
        highlightStore: (any CodeBlockHighlightStore)? = nil
    ) -> [RenderFragment] {
        RenderFragmentBuilder.buildRenderFragments(
            from: nodes,
            frozenCount: frozenCount,
            highlightStore: highlightStore
        )
    }
}
