import UIKit

enum AttributedStringAttributeFormatter {
    static func applyBlockquoteDepth(
        to attributedString: NSMutableAttributedString,
        depth: Int
    ) {
        guard depth > 0, attributedString.length > 0 else { return }

        let fullRange = NSRange(location: 0, length: attributedString.length)
        attributedString.enumerateAttribute(.blockquoteDepth, in: fullRange) { value, range, _ in
            guard value == nil else { return }
            attributedString.addAttribute(.blockquoteDepth, value: depth, range: range)
        }
    }

    static func makeAttributedStringWithBlockquoteDepth(
        _ attributedString: NSAttributedString,
        nestingContext: NestingContext
    ) -> NSAttributedString {
        guard nestingContext.blockquoteDepth > 0, attributedString.length > 0 else {
            return attributedString
        }

        let result = NSMutableAttributedString(attributedString: attributedString)
        applyBlockquoteDepth(to: result, depth: nestingContext.blockquoteDepth)
        return result
    }
}
