import QuillCore
import UIKit

final class CodeBlockAttachment: NSTextAttachment {
    let blockID: BlockIdentity
    let code: String
    weak var highlightStore: (any CodeBlockHighlightStore)?
    let language: String?
    let theme: QuillTheme

    init(
        blockID: BlockIdentity,
        language: String?,
        code: String,
        theme: QuillTheme
    ) {
        self.blockID = blockID
        self.code = code
        self.language = language
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
        CodeBlockAttachmentProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
}
