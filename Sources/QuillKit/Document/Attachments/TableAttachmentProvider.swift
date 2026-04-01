import QuillCore
import UIKit

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
        assert(Thread.isMainThread)
        view = MainActor.assumeIsolated {
            Self.makeSurfaceView(content: content)
        }
    }
    
    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        guard let attachment = textAttachment as? TableAttachment else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }

        let width = proposedLineFragment.width
        guard width > 0 else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }
        
        let content = TableSurfaceContent(from: attachment)
        let height = TableSurfaceLayoutBuilder.makeLayout(
            content: content,
            viewportWidth: width
        ).contentSize.height
        return CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }
}

private extension TableAttachmentProvider {
    enum Layout {
        static let fallbackSize = CGSize(width: 320, height: 120)
    }

    @MainActor
    static func makeSurfaceView(content: TableSurfaceContent) -> TableSurfaceView {
        let surfaceView = TableSurfaceView()
        surfaceView.configure(content: content)
        return surfaceView
    }
}
