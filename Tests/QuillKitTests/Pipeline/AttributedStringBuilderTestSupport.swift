import QuillCore
import UIKit

func attributedStringBuilderFont(in string: NSAttributedString, at location: Int = 0) -> UIFont? {
    string.attribute(.font, at: location, effectiveRange: nil) as? UIFont
}

func attributedStringBuilderSegments(_ blocks: Block...) -> [Block] {
    Array(blocks)
}
