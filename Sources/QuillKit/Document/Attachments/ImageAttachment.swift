import QuillCore
import UIKit

final class ImageAttachment: NSTextAttachment {
    let alt: String
    let blockID: BlockIdentity
    weak var imageLoadStore: (any ImageLoadStore)?
    let source: String?
    let theme: QuillTheme

    init(
        blockID: BlockIdentity,
        source: String?,
        alt: String,
        theme: QuillTheme = .default
    ) {
        self.alt = alt
        self.blockID = blockID
        self.source = source
        self.theme = theme
        super.init(data: nil, ofType: nil)

        allowsTextAttachmentView = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewProvider(
        for parentView: UIView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        ImageAttachmentProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
}
