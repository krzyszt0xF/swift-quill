import UIKit

@MainActor
final class DocumentTextView: UITextView {
    var onLinkSelection: ((URL) -> Void)?
    private let blockquoteDelegate = BlockquoteLayoutFragmentDelegate()
    
    var contentStorage: NSTextContentStorage? {
        textLayoutManager?.textContentManager as? NSTextContentStorage
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }

    init() {
        super.init(frame: .zero, textContainer: nil)

        isEditable = false
        isScrollEnabled = false
        isSelectable = true

        backgroundColor = .clear
        textContainerInset = .zero

        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension DocumentTextView {
    func configure() {
        textLayoutManager?.textContainer?.lineFragmentPadding = 0
        dataDetectorTypes = []
        linkTextAttributes = [:]
        textDragInteraction?.isEnabled = false
        blockquoteDelegate.install(on: textLayoutManager)
    }
}
