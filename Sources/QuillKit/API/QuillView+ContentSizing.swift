import UIKit

extension QuillView {
    @MainActor
    package func fittedContentSize(for width: CGFloat) -> CGSize {
        guard width.isFinite, width > 0 else {
            return CGSize(width: 0, height: 1)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if abs(bounds.width - width) > 0.5 {
            var updatedBounds = bounds
            updatedBounds.size.width = width
            bounds = updatedBounds
        }

        setNeedsLayout()
        layoutIfNeeded()

        let documentView = streamCoordinator.hostView
        documentView.setNeedsLayout()
        documentView.layoutIfNeeded()
        documentView.invalidateIntrinsicContentSize()

        let measuredHeight = ceil(documentView.intrinsicContentSize.height)

        CATransaction.commit()

        return CGSize(
            width: width,
            height: measuredHeight.isFinite ? max(1, measuredHeight) : 1
        )
    }
}
