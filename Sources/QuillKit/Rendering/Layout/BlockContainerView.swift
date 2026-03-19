import UIKit

@MainActor
final class BlockContainerView: UIView {
    private(set) var blockViews: [UIView] = []

    private var heightCache = BlockHeightCache()
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
        heightCache.invalidateFromIndex(index)
        setNeedsLayout()
    }

    func invalidateAllHeightCaches() {
        heightCache.invalidateAll()
    }

    func invalidateBlockLayout(for view: UIView) {
        guard let index = blockViews.firstIndex(where: { $0 === view }) else { return }
        
        heightCache.invalidateBlock(at: index, view: view)
        setNeedsLayout()
    }

    func removeAllBlocks() {
        for view in blockViews {
            view.removeFromSuperview()
        }
        blockViews.removeAll()
        heightCache.invalidateAll()
        spacingAfter.removeAll()
        setNeedsLayout()
    }

    func removeBlock(at index: Int) {
        let view = blockViews.remove(at: index)
        view.removeFromSuperview()
        heightCache.removeView(view)
        spacingAfter.removeValue(forKey: index)
        rebuildSpacingIndices(after: index)
        
        heightCache.invalidateFromIndex(index)
        setNeedsLayout()
    }

    func totalHeight(for width: CGFloat) -> CGFloat {
        guard !blockViews.isEmpty, width > 0 else { return 0 }

        let widthDidChange = heightCache.handleWidthChange(width, tolerance: layoutTolerance)

        var total: CGFloat = 0
        for (index, view) in blockViews.enumerated() {
            total += heightCache.measureHeight(
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
        heightCache.removeView(oldView)
        
        blockViews[index] = view
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        applyStructuralSpacing(for: view, at: index)
        
        heightCache.removeHeightEntry(at: index)
        setNeedsLayout()
    }
}

private extension BlockContainerView {
    var layoutTolerance: CGFloat { 0.5 }

    func performRelayoutPass(for width: CGFloat) -> CGFloat {
        let widthDidChange = heightCache.handleWidthChange(width, tolerance: layoutTolerance)

        var currentY: CGFloat = 0
        for (index, view) in blockViews.enumerated() {
            let height = heightCache.measureHeight(
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

    func layoutStructuredViewIfNeeded(_ view: UIView) {
        guard view is CodeBlockView || view is PlaceholderBlockView else { return }
        
        view.setNeedsLayout()
        view.layoutIfNeeded()
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
}
