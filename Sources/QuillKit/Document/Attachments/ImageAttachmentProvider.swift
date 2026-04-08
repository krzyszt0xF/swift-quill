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
        let theme = attachment.theme
        view = executeIsolated {
            ImageBlockView(
                from: content,
                imageLoadStore: imageLoadStore,
                theme: theme
            )
        }
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        let fallbackSize = CGSize(width: 320, height: 180)
        guard let attachment = textAttachment as? ImageAttachment else {
            return CGRect(origin: .zero, size: fallbackSize)
        }

        let width = proposedLineFragment.width
        guard width > 0 else {
            return CGRect(origin: .zero, size: fallbackSize)
        }

        let resolvedAspectRatio = attachment.imageLoadStore?.resolvedAspectRatio(for: attachment.blockID)
            ?? attachment.theme.image.fallbackAspectRatio
        let aspectRatio = max(0.01, resolvedAspectRatio)
        let height = min(width / aspectRatio, attachment.theme.image.maxHeight)
        return CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }
}

private extension ImageBlockView {
    convenience init(
        from content: ImageBlockContent,
        imageLoadStore: (any ImageLoadStore)?,
        theme: QuillTheme) {
            self.init(theme: theme)
            let retryEnabled = imageLoadStore?.retryEnabled ?? true
            configure(
                content: content,
                retryEnabled: retryEnabled
            )

            if let imageLoadResult = imageLoadStore?.loadResult(for: content.blockID) {
                apply(imageLoadResult: imageLoadResult)
            }

            onRetry = { [weak imageLoadStore, weak self] in
                self?.configure(
                    content: content,
                    retryEnabled: imageLoadStore?.retryEnabled ?? true
                )
                imageLoadStore?.retryLoad(blockID: content.blockID, source: content.source)
            }

            imageLoadStore?.register(sink: self, for: content.blockID)
        }
}
