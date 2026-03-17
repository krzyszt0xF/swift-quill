import UIKit

@MainActor
protocol BlockRevealAnimating: AnyObject {
    var minimumMeasuredHeight: CGFloat { get }
    var revealProgress: CGFloat { get set }

    func currentRevealHeight() -> CGFloat
    func finishBlockReveal()
    func measuredHeight(for width: CGFloat) -> CGFloat
    func prepareForBlockReveal()
    func setBlockRevealProgress(_ progress: CGFloat) -> Bool
}

extension BlockRevealAnimating where Self: UIView {
    func currentRevealHeight() -> CGFloat {
        let width = resolvedMeasurementWidth(from: bounds.width)
        return scaledHeight(for: width > 0 ? measuredHeight(for: width) : minimumMeasuredHeight)
    }

    func finishBlockReveal() {
        revealProgress = 1
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func prepareForBlockReveal() {
        revealProgress = 0
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func resolvedMeasurementWidth(from proposedWidth: CGFloat) -> CGFloat {
        if proposedWidth > 0, proposedWidth != UIView.noIntrinsicMetric {
            return proposedWidth
        }
        return bounds.width
    }

    var revealIntrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: revealScaledHeight(proposedWidth: bounds.width))
    }

    func revealScaledHeight(proposedWidth: CGFloat) -> CGFloat {
        let measuredWidth = resolvedMeasurementWidth(from: proposedWidth)
        guard measuredWidth > 0 else {
            return scaledHeight(for: minimumMeasuredHeight)
        }
        return scaledHeight(for: measuredHeight(for: measuredWidth))
    }

    func revealSizeThatFits(_ size: CGSize) -> CGSize {
        let width = resolvedMeasurementWidth(from: size.width)
        return CGSize(width: width > 0 ? width : size.width, height: revealScaledHeight(proposedWidth: size.width))
    }

    func scaledHeight(for height: CGFloat) -> CGFloat {
        ceil(max(0, height * revealProgress))
    }

    func setBlockRevealProgress(_ progress: CGFloat) -> Bool {
        let clampedProgress = min(max(progress, 0), 1)
        guard abs(clampedProgress - revealProgress) > 0.001 else { return false }

        let oldHeight = currentRevealHeight()
        revealProgress = clampedProgress
        let newHeight = currentRevealHeight()

        invalidateIntrinsicContentSize()
        setNeedsLayout()
        return abs(newHeight - oldHeight) > 0.5
    }
}
