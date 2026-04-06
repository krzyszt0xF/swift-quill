import QuillCore
import UIKit

enum AttributedStringBuilder {
    static func buildDocument(
        from fragments: [RenderFragment]
    ) -> NSAttributedString {
        RenderDocumentAssembler.buildDocument(from: fragments)
    }

    static func buildRenderFragments(
        from nodes: [BlockNode],
        frozenCount: Int,
        highlightStore: (any CodeBlockHighlightStore)? = nil,
        imageLoadStore: (any ImageLoadStore)? = nil,
        imageAppearance: ImageAppearance = .default
    ) -> [RenderFragment] {
        RenderFragmentBuilder.buildRenderFragments(
            from: nodes,
            frozenCount: frozenCount,
            highlightStore: highlightStore,
            imageLoadStore: imageLoadStore,
            imageAppearance: imageAppearance
        )
    }
}
