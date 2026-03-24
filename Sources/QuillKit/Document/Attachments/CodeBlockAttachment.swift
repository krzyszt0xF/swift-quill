import QuillCore
import UIKit

final class CodeBlockAttachment: NSTextAttachment {
    private var hasAnimatedAppearance = false
    let blockID: BlockIdentity
    let code: String
    let language: String?

    init(blockID: BlockIdentity, language: String?, code: String) {
        self.blockID = blockID
        self.code = code
        self.language = language
        super.init(data: nil, ofType: nil)

        allowsTextAttachmentView = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func consumePendingAppearanceAnimation(isReduceMotionEnabled: Bool) -> Bool {
        guard
            isReduceMotionEnabled == false,
            hasAnimatedAppearance == false
        else { return false }

        hasAnimatedAppearance = true
        return true
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
