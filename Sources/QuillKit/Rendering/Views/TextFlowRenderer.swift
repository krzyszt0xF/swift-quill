import UIKit

struct TextFlowRenderer {
    func draw(textLayoutManager: NSTextLayoutManager, in context: CGContext) {
        textLayoutManager.enumerateTextLayoutFragments(
            from: textLayoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            fragment.draw(at: fragment.layoutFragmentFrame.origin, in: context)
            return true
        }
    }

    func drawBlockquoteBars(
        attributedString: NSAttributedString,
        textLayoutManager: NSTextLayoutManager,
        textContentStorage: NSTextContentStorage,
        in context: CGContext
    ) {
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttribute(.blockquoteDepth, in: fullRange) { value, range, _ in
            guard let depth = value as? Int, depth > 0 else {
                return
            }

            let yExtents = yRange(
                for: range,
                textLayoutManager: textLayoutManager,
                textContentStorage: textContentStorage
            )
            guard yExtents.max > yExtents.min else {
                return
            }

            let xOrigin = CGFloat(depth - 1) * 16
            let barRect = CGRect(x: xOrigin, y: yExtents.min, width: 3, height: yExtents.max - yExtents.min)
            context.setFillColor(UIColor.systemGray3.cgColor)
            context.fill(barRect)
        }
    }

    func yRange(
        for characterRange: NSRange,
        textLayoutManager: NSTextLayoutManager,
        textContentStorage: NSTextContentStorage
    ) -> (min: CGFloat, max: CGFloat) {
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = 0

        guard let startLocation = textLayoutManager.location(
            textLayoutManager.documentRange.location,
            offsetBy: characterRange.location
        ) else { return (0, 0) }

        guard let endLocation = textLayoutManager.location(
            startLocation,
            offsetBy: characterRange.length
        ) else { return (0, 0) }

        let textRange = NSTextRange(location: startLocation, end: endLocation)

        textLayoutManager.enumerateTextLayoutFragments(
            from: textRange?.location,
            options: [.ensuresLayout]
        ) { fragment in
            let location = fragment.rangeInElement.location
            guard let textRange,
                  location.compare(textRange.endLocation) != .orderedDescending
            else {
                return false
            }

            let frame = fragment.layoutFragmentFrame
            if frame.minY < minY {
                minY = frame.minY
            }
            if frame.maxY > maxY {
                maxY = frame.maxY
            }

            return true
        }

        return (minY == .greatestFiniteMagnitude ? 0 : minY, maxY)
    }
}
