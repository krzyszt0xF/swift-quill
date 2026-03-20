import UIKit

struct TextFlowLinkInteraction {
    func linkURL(
        at point: CGPoint,
        visibleCharacterCount: Int,
        textLayoutManager: NSTextLayoutManager,
        textContentStorage: NSTextContentStorage,
        bounds: CGRect,
        originalAttributedString: NSAttributedString?,
        updateLayout: () -> Void) -> URL? {
            let characterIndex = resolvedCharacterIndex(
                at: point,
                textLayoutManager: textLayoutManager,
                textContentStorage: textContentStorage,
                bounds: bounds,
                updateLayout: updateLayout)
            guard
                let characterIndex,
                characterIndex < visibleCharacterCount
            else { return nil }
            
            let attributedString = originalAttributedString ?? textContentStorage.attributedString
            guard let attributedString,
                  characterIndex >= 0,
                  characterIndex < attributedString.length else {
                return nil
            }
            
            return attributedString.attribute(.link, at: characterIndex, effectiveRange: nil) as? URL
        }
    
    func findLayoutFragment(
        containing point: CGPoint,
        textLayoutManager: NSTextLayoutManager,
        bounds: CGRect,
        updateLayout: () -> Void
    ) -> NSTextLayoutFragment? {
        guard bounds.contains(point) else { return nil }

        updateLayout()

        var matchedFragment: NSTextLayoutFragment?
        textLayoutManager.enumerateTextLayoutFragments(
            from: textLayoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            guard fragment.layoutFragmentFrame.contains(point) else {
                return true
            }

            matchedFragment = fragment
            return false
        }

        return matchedFragment
    }

    func resolvedCharacterIndex(
        at point: CGPoint,
        textLayoutManager: NSTextLayoutManager,
        textContentStorage: NSTextContentStorage,
        bounds: CGRect,
        updateLayout: () -> Void
    ) -> Int? {
        guard let fragment = findLayoutFragment(
            containing: point,
            textLayoutManager: textLayoutManager,
            bounds: bounds,
            updateLayout: updateLayout
        ) else {
            return nil
        }

        let fragmentPoint = CGPoint(
            x: point.x - fragment.layoutFragmentFrame.minX,
            y: point.y - fragment.layoutFragmentFrame.minY
        )
        guard let lineFragment = fragment.textLineFragments.first(where: {
            $0.typographicBounds.minY <= fragmentPoint.y && fragmentPoint.y <= $0.typographicBounds.maxY
        }) else {
            return nil
        }

        return resolvedCharacterIndex(
            from: lineFragment,
            in: fragment,
            textContentStorage: textContentStorage,
            fragmentPoint: fragmentPoint
        )
    }

    func resolvedCharacterIndex(
        from lineFragment: NSTextLineFragment,
        in fragment: NSTextLayoutFragment,
        textContentStorage: NSTextContentStorage,
        fragmentPoint: CGPoint
    ) -> Int? {
        guard lineFragment.characterRange.length > 0 else { return nil }

        let lineBounds = lineFragment.typographicBounds
        guard fragmentPoint.x >= lineBounds.minX,
              fragmentPoint.x <= lineBounds.maxX else {
            return nil
        }

        let linePoint = CGPoint(
            x: fragmentPoint.x - lineBounds.minX,
            y: fragmentPoint.y - lineBounds.minY
        )
        let lineCharacterIndex = lineFragment.characterIndex(for: linePoint)
        let lineCharacterRange = lineFragment.characterRange
        let elementCharacterIndex: Int
        if lineCharacterIndex >= lineCharacterRange.location,
           lineCharacterIndex < lineCharacterRange.upperBound {
            elementCharacterIndex = lineCharacterIndex
        } else {
            elementCharacterIndex = lineCharacterRange.location + lineCharacterIndex
        }

        let clampedElementIndex = min(
            max(elementCharacterIndex, lineCharacterRange.location),
            lineCharacterRange.upperBound - 1
        )
        let paragraphStart = textContentStorage.offset(
            from: textContentStorage.documentRange.location,
            to: fragment.rangeInElement.location
        )
        
        return paragraphStart + clampedElementIndex
    }
}
