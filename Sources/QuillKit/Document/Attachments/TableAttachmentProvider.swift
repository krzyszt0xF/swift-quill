import QuillCore
import UIKit

@MainActor
final class TableAttachmentProvider: NSTextAttachmentViewProvider {
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
        guard let attachment = textAttachment as? TableAttachment else { return }

        let content = TableSurfaceContent(from: attachment)
        let theme = attachment.theme
        view = executeIsolated {
            let surfaceView = TableSurfaceView(theme: theme)
            surfaceView.configure(content: content)
            return surfaceView
        }
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        let fallbackSize = CGSize(width: 320, height: 120)
        guard let attachment = textAttachment as? TableAttachment else {
            return CGRect(origin: .zero, size: fallbackSize)
        }

        let width = proposedLineFragment.width
        guard width > 0 else {
            return CGRect(origin: .zero, size: fallbackSize)
        }

        let content = TableSurfaceContent(from: attachment)
        let height = TableSurfaceLayoutBuilder.makeLayout(
            content: content,
            viewportWidth: width,
            theme: attachment.theme
        ).contentSize.height
        return CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }
}
