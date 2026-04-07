import UIKit

@MainActor
final class ImageAttachmentProvider: NSTextAttachmentViewProvider {
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
        guard let attachment = textAttachment as? ImageAttachment else { return }

        let content = ImageBlockContent(from: attachment)
        let imageLoadStore = attachment.imageLoadStore

        view = Self.makeImageView(
            from: content,
            imageLoadStore: imageLoadStore,
            theme: attachment.theme
        )
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        guard let attachment = textAttachment as? ImageAttachment else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }

        let width = proposedLineFragment.width
        guard width > 0 else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }

        let resolvedAspectRatio = attachment.imageLoadStore?.resolvedAspectRatio(for: attachment.blockID)
            ?? attachment.theme.image.fallbackAspectRatio
        let aspectRatio = max(0.01, resolvedAspectRatio)
        let height = min(width / aspectRatio, attachment.theme.image.maxHeight)
        return CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }
}

private extension ImageAttachmentProvider {
    enum Layout {
        static let fallbackSize = CGSize(width: 320, height: 180)
    }

    static func makeImageView(
        from content: ImageBlockContent,
        imageLoadStore: (any ImageLoadStore)?,
        theme: QuillTheme
    ) -> ImageBlockView {
        let view = ImageBlockView(theme: theme)
        let retryEnabled = imageLoadStore?.retryEnabled ?? true
        view.configure(
            content: content,
            retryEnabled: retryEnabled
        )

        if let imageLoadResult = imageLoadStore?.loadResult(for: content.blockID) {
            view.apply(imageLoadResult: imageLoadResult)
        }

        view.onRetry = { [weak imageLoadStore, weak view] in
            let retryEnabled = imageLoadStore?.retryEnabled ?? true
            view?.configure(
                content: content,
                retryEnabled: retryEnabled
            )
            imageLoadStore?.retryLoad(blockID: content.blockID, source: content.source)
        }

        imageLoadStore?.register(sink: view, for: content.blockID)
        return view
    }
}
