import UIKit

@MainActor
protocol BlockRevealAnimating: AnyObject {
    var revealProgress: CGFloat { get set }

    func currentRevealHeight() -> CGFloat
    func finishBlockReveal()
    func prepareForBlockReveal()
    func setBlockRevealProgress(_ progress: CGFloat) -> Bool
}

extension BlockRevealAnimating where Self: UIView {
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
