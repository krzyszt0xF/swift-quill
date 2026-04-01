import QuillCore
import QuillCoreTestSupport
@testable import QuillKit
import UIKit

func attributedStringBuilderFont(in string: NSAttributedString, at location: Int = 0) -> UIFont? {
    string.attribute(.font, at: location, effectiveRange: nil) as? UIFont
}

func makePipelineDocument(
    _ blocks: Block...,
    frozenCount: Int? = nil
) -> NSAttributedString {
    makePipelineDocument(
        from: Array(blocks),
        frozenCount: frozenCount
    )
}

func makePipelineDocument(
    from blocks: [Block],
    frozenCount: Int? = nil
) -> NSAttributedString {
    let fragments = AttributedStringBuilder.buildRenderFragments(
        from: makeNodes(blocks),
        frozenCount: frozenCount ?? blocks.count
    )
    return AttributedStringBuilder.buildDocument(from: fragments)
}
