import UIKit

@MainActor
final class DocumentTextView: UITextView {
    var onLinkSelection: ((URL) -> Void)?
    private let blockquoteDelegate = BlockquoteLayoutFragmentDelegate()
    
    var contentStorage: NSTextContentStorage? {
        textLayoutManager?.textContentManager as? NSTextContentStorage
    }

    var selectionTouchesCodeBlockAttachment: Bool {
        guard selectedRange.location != NSNotFound,
              let attributedString = contentStorage?.attributedString,
              attributedString.length > 0
        else { return false }

        let lowerBound = max(0, selectedRange.location)
        let upperBound = min(attributedString.length, selectedRange.location + max(selectedRange.length, 1))
        guard lowerBound < upperBound else { return false }

        for index in lowerBound..<upperBound {
            if attributedString.attribute(.attachment, at: index, effectiveRange: nil) is CodeBlockAttachment {
                return true
            }
        }

        return false
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
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard selectionTouchesCodeBlockAttachment == false else {
            return false
        }

        return super.canPerformAction(action, withSender: sender)
    }
}

private extension DocumentTextView {
    func configure() {
        textLayoutManager?.textContainer?.lineFragmentPadding = 0
        dataDetectorTypes = []
        linkTextAttributes = [:]
        blockquoteDelegate.install(on: textLayoutManager)
    }
}
