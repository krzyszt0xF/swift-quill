import QuillKit
import SwiftUI

extension QuillView {
    @MainActor
    func calculateFittedSize(for proposal: ProposedViewSize) -> CGSize? {
        let screenWidth = window?.screen.bounds.width ?? UIScreen.main.bounds.width
        let fallbackWidth = max(bounds.width, screenWidth)
        let width = resolvedWidth(
            proposalWidth: proposal.width,
            fallbackWidth: fallbackWidth
        )
        guard let width else { return nil }

        return fittedContentSize(for: width)
    }

    @MainActor
    func configureHeightInvalidation() {
        onHeightChange = { [weak self] _, _ in
            self?.invalidateIntrinsicContentSize()
        }
    }
}

private extension QuillView {
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
}
