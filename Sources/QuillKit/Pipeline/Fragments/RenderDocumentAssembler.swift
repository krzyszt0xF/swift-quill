import UIKit

enum RenderDocumentAssembler {
    static func buildDocument(
        from fragments: [RenderFragment]
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, fragment) in fragments.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }

            let fragmentStart = result.length
            result.append(fragment.attributedString)

            let fragmentRange = NSRange(
                location: fragmentStart,
                length: result.length - fragmentStart
            )
            result.addAttribute(
                .contentBlockID,
                value: fragment.contentBlockID,
                range: fragmentRange
            )
            result.addAttribute(
                .ownerBlockID,
                value: fragment.ownerBlockID,
                range: fragmentRange
            )
            if fragment.blockquoteDepth > 0 {
                result.addAttribute(
                    .blockquoteDepth,
                    value: fragment.blockquoteDepth,
                    range: fragmentRange
                )
            }
        }

        return result
    }
}
