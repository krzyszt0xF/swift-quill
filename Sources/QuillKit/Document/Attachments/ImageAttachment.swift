import QuillCore
import UIKit

final class ImageAttachment: NSTextAttachment {
    let alt: String
    let appearance: ImageAppearance
    let blockID: BlockIdentity
    weak var imageLoadStore: (any ImageLoadStore)?
    let source: String?

    init(
        blockID: BlockIdentity,
        source: String?,
        alt: String,
        appearance: ImageAppearance
    ) {
        self.alt = alt
        self.appearance = appearance
        self.blockID = blockID
        self.source = source
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
