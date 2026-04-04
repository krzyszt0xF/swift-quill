import SwiftUI

extension UIView {
    @MainActor
    func calculateFittedSize(for proposal: ProposedViewSize) -> CGSize? {
        func resolvedWidth(
            proposalWidth: CGFloat?,
            fallbackWidth: CGFloat
        ) -> CGFloat? {
            if let proposalWidth,
               proposalWidth.isFinite,
               proposalWidth > 0 {
                return proposalWidth
            }

            guard fallbackWidth.isFinite, fallbackWidth > 0 else { return nil }
            return fallbackWidth
        }

        let screenWidth = window?.screen.bounds.width ?? UIScreen.main.bounds.width
        let fallbackWidth = max(bounds.width, screenWidth)
        let width = resolvedWidth(
            proposalWidth: proposal.width,
            fallbackWidth: fallbackWidth
        )
        guard let width else { return nil }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if abs(bounds.width - width) > 0.5 {
            var updatedBounds = bounds
            updatedBounds.size.width = width
            bounds = updatedBounds
        }
        setNeedsLayout()
        layoutIfNeeded()

        let fitting = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let size = systemLayoutSizeFitting(
            fitting,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        CATransaction.commit()

        return CGSize(
            width: width,
            height: size.height.isFinite ? max(1, size.height) : 1
        )
    }

}
