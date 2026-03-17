import UIKit

@MainActor
struct BlockHeightCache {
    private var heightCache: [Int: CGFloat] = [:]
    private var lastLayoutWidth: CGFloat = 0
    private var measuredHeightByView: [ObjectIdentifier: (width: CGFloat, height: CGFloat)] = [:]

    mutating func invalidateAll() {
        heightCache.removeAll()
        measuredHeightByView.removeAll()
    }

    mutating func invalidateBlock(at index: Int, view: UIView) {
        heightCache.removeValue(forKey: index)
        measuredHeightByView.removeValue(forKey: ObjectIdentifier(view))
    }

    mutating func invalidateFromIndex(_ index: Int) {
        for key in heightCache.keys where key >= index {
            heightCache.removeValue(forKey: key)
        }
    }

    mutating func measureHeight(
        for view: UIView,
        at index: Int,
        width: CGFloat,
        widthDidChange: Bool
    ) -> CGFloat {
        if let cached = heightCache[index] {
            return cached
        }

        let viewID = ObjectIdentifier(view)
        if !widthDidChange,
           let measured = measuredHeightByView[viewID],
           widthsAreEquivalent(measured.width, width),
           measured.height > 0 {
            heightCache[index] = measured.height
            return measured.height
        }

        if !widthDidChange,
           widthsAreEquivalent(view.bounds.width, width),
           view.bounds.height > 0 {
            view.layoutIfNeeded()
            var height = view.intrinsicContentSize.height
            if height < 0 {
                height = view.bounds.height
            }
            if height > 0 {
                heightCache[index] = height
                measuredHeightByView[viewID] = (width: width, height: height)
            }
            return max(height, 0)
        }

        let hadWidthMismatch = widthsAreEquivalent(view.bounds.width, width) == false
        if hadWidthMismatch {
            var frame = view.frame
            frame.size.width = width
            view.frame = frame
        }

        if widthDidChange || hadWidthMismatch || view.bounds.height <= 0 {
            view.layoutIfNeeded()
        }

        var height = view.intrinsicContentSize.height
        if height < 0 {
            height = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        }

        if height > 0 {
            heightCache[index] = height
            measuredHeightByView[viewID] = (width: width, height: height)
        }

        return max(height, 0)
    }

    mutating func removeView(_ view: UIView) {
        measuredHeightByView.removeValue(forKey: ObjectIdentifier(view))
    }

    mutating func removeHeightEntry(at index: Int) {
        heightCache.removeValue(forKey: index)
    }

    mutating func handleWidthChange(_ width: CGFloat, tolerance: CGFloat) -> Bool {
        let widthDidChange = abs(width - lastLayoutWidth) > tolerance
        if widthDidChange {
            heightCache.removeAll()
            lastLayoutWidth = width
        }
        return widthDidChange
    }
}

private extension BlockHeightCache {
    func widthsAreEquivalent(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) <= 0.5
    }
}
