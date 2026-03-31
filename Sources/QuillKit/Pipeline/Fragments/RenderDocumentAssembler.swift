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

            let fragmentString = NSMutableAttributedString(attributedString: fragment.attributedString)
            let fullRange = NSRange(location: 0, length: fragmentString.length)
            fragmentString.addAttribute(.contentBlockID, value: fragment.contentBlockID, range: fullRange)
            fragmentString.addAttribute(.ownerBlockID, value: fragment.ownerBlockID, range: fullRange)
            result.append(fragmentString)
        }

        return result
    }
}
