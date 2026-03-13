import UIKit

@MainActor
final class BlockContainerView: UIView {
    private(set) var blockViews: [UIView] = []

    private var heightCache: [Int: CGFloat] = [:]
    private var lastLayoutWidth: CGFloat = 0
    private var measuredHeightByView: [ObjectIdentifier: (width: CGFloat, height: CGFloat)] = [:]
    private var spacingAfter: [Int: CGFloat] = [:]

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: totalHeight(for: bounds.width))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        let totalHeight = performRelayoutPass(for: bounds.width)
        if abs(bounds.height - totalHeight) > layoutTolerance {
            invalidateIntrinsicContentSize()
        }
    }

    func insertBlock(_ view: UIView, at index: Int) {
        blockViews.insert(view, at: index)
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        applyStructuralSpacing(for: view, at: index)
        invalidateHeightCache(from: index)
        setNeedsLayout()
    }

    func invalidateAllHeightCaches() {
        heightCache.removeAll()
    }

    func invalidateBlockLayout(for view: UIView) {
        guard let index = blockViews.firstIndex(where: { $0 === view }) else { return }
        heightCache.removeValue(forKey: index)
        measuredHeightByView.removeValue(forKey: ObjectIdentifier(view))
        setNeedsLayout()
    }

    func removeAllBlocks() {
        for view in blockViews {
            view.removeFromSuperview()
        }
        blockViews.removeAll()
        heightCache.removeAll()
        measuredHeightByView.removeAll()
        spacingAfter.removeAll()
        setNeedsLayout()
    }

    func removeBlock(at index: Int) {
        let view = blockViews.remove(at: index)
        view.removeFromSuperview()
        measuredHeightByView.removeValue(forKey: ObjectIdentifier(view))
        spacingAfter.removeValue(forKey: index)
        rebuildSpacingIndices(after: index)
        invalidateHeightCache(from: index)
        setNeedsLayout()
    }

    func totalHeight(for width: CGFloat) -> CGFloat {
        guard !blockViews.isEmpty, width > 0 else { return 0 }

        let widthDidChange = abs(width - lastLayoutWidth) > layoutTolerance
        if widthDidChange {
            heightCache.removeAll()
            lastLayoutWidth = width
        }

        var total: CGFloat = 0
        for (index, view) in blockViews.enumerated() {
            total += measureHeight(
                for: view,
                at: index,
                width: width,
                widthDidChange: widthDidChange
            )
            total += spacingAfter[index] ?? 0
        }
        return total
    }

    func updateBlock(at index: Int, with view: UIView) {
        let oldView = blockViews[index]
        oldView.removeFromSuperview()
        measuredHeightByView.removeValue(forKey: ObjectIdentifier(oldView))
        blockViews[index] = view
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        applyStructuralSpacing(for: view, at: index)
        heightCache.removeValue(forKey: index)
        setNeedsLayout()
    }
}

private extension BlockContainerView {
    var layoutTolerance: CGFloat { 0.5 }

    func performRelayoutPass(for width: CGFloat) -> CGFloat {
        let widthDidChange = abs(width - lastLayoutWidth) > layoutTolerance
        if widthDidChange {
            heightCache.removeAll()
            lastLayoutWidth = width
        }

        var currentY: CGFloat = 0
        for (index, view) in blockViews.enumerated() {
            let height = measureHeight(
                for: view,
                at: index,
                width: width,
                widthDidChange: widthDidChange
            )
            let targetFrame = CGRect(x: 0, y: currentY, width: width, height: height)
            if framesAreEquivalent(view.frame, targetFrame) == false {
                view.frame = targetFrame
                layoutStructuredViewIfNeeded(view)
            }
            currentY += height + (spacingAfter[index] ?? 0)
        }

        return currentY
    }

    func applyStructuralSpacing(for view: UIView, at index: Int) {
        if view is CodeBlockView || view is PlaceholderBlockView {
            spacingAfter[index] = 12
        }
    }

    func framesAreEquivalent(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) <= layoutTolerance &&
            abs(lhs.origin.y - rhs.origin.y) <= layoutTolerance &&
            abs(lhs.width - rhs.width) <= layoutTolerance &&
            abs(lhs.height - rhs.height) <= layoutTolerance
    }

    func invalidateHeightCache(from index: Int) {
        for key in heightCache.keys where key >= index {
            heightCache.removeValue(forKey: key)
        }
    }

    func layoutStructuredViewIfNeeded(_ view: UIView) {
        guard view is CodeBlockView || view is PlaceholderBlockView else { return }
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    func measureHeight(
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
            heightCache[index] = view.bounds.height
            measuredHeightByView[viewID] = (width: width, height: view.bounds.height)
            return view.bounds.height
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
        if height <= 0 || height == UIView.noIntrinsicMetric {
            height = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        }

        if height > 0 {
            heightCache[index] = height
            measuredHeightByView[viewID] = (width: width, height: height)
        }

        return max(height, 0)
    }

    func rebuildSpacingIndices(after removedIndex: Int) {
        var newSpacing: [Int: CGFloat] = [:]
        for (key, value) in spacingAfter {
            if key < removedIndex {
                newSpacing[key] = value
            } else if key > removedIndex {
                newSpacing[key - 1] = value
            }
        }
        spacingAfter = newSpacing
    }

    func widthsAreEquivalent(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool {
        abs(lhs - rhs) <= layoutTolerance
    }
}
