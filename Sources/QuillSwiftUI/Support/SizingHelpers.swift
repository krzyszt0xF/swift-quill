import SwiftUI

@MainActor
func fittedSize(for view: UIView, proposal: ProposedViewSize) -> CGSize? {
    let screenWidth = view.window?.screen.bounds.width ?? UIScreen.main.bounds.width
    let fallbackWidth = max(view.bounds.width, screenWidth)
    let width = proposal.width ?? fallbackWidth
    guard width > 0 else { return nil }

    CATransaction.begin()
    CATransaction.setDisableActions(true)

    if abs(view.bounds.width - width) > 0.5 {
        var bounds = view.bounds
        bounds.size.width = width
        view.bounds = bounds
    }
    view.setNeedsLayout()
    view.layoutIfNeeded()

    let fitting = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
    let size = view.systemLayoutSizeFitting(
        fitting,
        withHorizontalFittingPriority: .required,
        verticalFittingPriority: .fittingSizeLevel
    )

    CATransaction.commit()
    
    return CGSize(width: width, height: max(1, size.height))
}
