import UIKit

struct TextFlowLayoutController {
    private var cachedPrefixHeight: CGFloat = 0
    private var cachedPrefixHeightKey: (revealIndex: Int, width: CGFloat) = (-1, 0)

    mutating func resetCache() {
        cachedPrefixHeightKey = (-1, 0)
    }

    func computeFullLayoutHeight(textLayoutManager: NSTextLayoutManager) -> CGFloat {
        var maxY: CGFloat = 0
        textLayoutManager.enumerateTextLayoutFragments(
            from: textLayoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragmentMaxY = fragment.layoutFragmentFrame.maxY
            if fragmentMaxY > maxY {
                maxY = fragmentMaxY
            }
            return true
        }
        
        return maxY
    }

    mutating func computeHeight(
        textLayoutManager: NSTextLayoutManager,
        textContentStorage: NSTextContentStorage,
        originalAttributedString: NSAttributedString?,
        lastRevealedIndex: Int,
        boundsWidth: CGFloat
    ) -> CGFloat {
        if let originalAttributedString {
            let total = originalAttributedString.length
            if lastRevealedIndex == 0 {
                return 0
            } else if lastRevealedIndex >= total {
                return computeFullLayoutHeight(textLayoutManager: textLayoutManager)
            } else {
                return visiblePrefixHeight(
                    forWidth: boundsWidth,
                    lastRevealedIndex: lastRevealedIndex,
                    originalAttributedString: originalAttributedString
                )
            }
        } else {
            var maxY = computeFullLayoutHeight(textLayoutManager: textLayoutManager)
            if maxY == 0,
               let attributedString = textContentStorage.attributedString,
               attributedString.length > 0 {
                let boundingSize = CGSize(width: boundsWidth, height: CGFloat.greatestFiniteMagnitude)
                maxY = attributedString.boundingRect(
                    with: boundingSize,
                    options: [.usesLineFragmentOrigin],
                    context: nil
                ).height
            }
            
            return maxY
        }
    }

    mutating func visiblePrefixHeight(
        forWidth width: CGFloat,
        lastRevealedIndex: Int,
        originalAttributedString: NSAttributedString
    ) -> CGFloat {
        guard width > 0,
              lastRevealedIndex > 0,
              lastRevealedIndex < originalAttributedString.length
        else { return 0 }

        let key = (revealIndex: lastRevealedIndex, width: width)
        if key == cachedPrefixHeightKey {
            return cachedPrefixHeight
        }

        let visiblePrefix = originalAttributedString.attributedSubstring(
            from: NSRange(location: 0, length: lastRevealedIndex)
        )
        let boundingSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let height = ceil(
            visiblePrefix.boundingRect(
                with: boundingSize,
                options: [.usesLineFragmentOrigin],
                context: nil
            ).height
        )

        cachedPrefixHeight = height
        cachedPrefixHeightKey = key
        
        return height
    }
}
