import UIKit

@MainActor
final class CodeBlockAttachmentProvider: NSTextAttachmentViewProvider {
    override init(
        textAttachment: NSTextAttachment,
        parentView: UIView?,
        textLayoutManager: NSTextLayoutManager?,
        location: any NSTextLocation
    ) {
        super.init(
            textAttachment: textAttachment,
            parentView: parentView,
            textLayoutManager: textLayoutManager,
            location: location
        )

        tracksTextAttachmentViewBounds = true
    }

    override func loadView() {
        guard let attachment = textAttachment as? CodeBlockAttachment else { return }

        let view = CodeBlockView()
        view.configure(language: attachment.language, code: attachment.code)
        self.view = view
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        guard let attachment = textAttachment as? CodeBlockAttachment else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }

        let width = proposedLineFragment.width
        guard width > 0 else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }

        let height = CodeBlockView.measuredHeight(
            language: attachment.language,
            code: attachment.code
        )
        return CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }
}

private extension CodeBlockAttachmentProvider {
    enum Layout {
        static let fallbackSize = CGSize(width: 320, height: 80)
    }
}
