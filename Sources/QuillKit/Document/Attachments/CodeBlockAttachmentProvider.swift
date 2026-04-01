import UIKit

final class CodeBlockAttachmentProvider: NSTextAttachmentViewProvider {
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
        guard let attachment = textAttachment as? CodeBlockAttachment else { return }

        let content = CodeBlockContent(from: attachment)
        let store = attachment.highlightStore
        
        assert(Thread.isMainThread)
        view = MainActor.assumeIsolated {
            Self.makeBlockView(from: content, highlightStore: store)
        }
    }

    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: any NSTextLocation,
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        guard let attachment = textAttachment as? CodeBlockAttachment else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }

        let width = proposedLineFragment.width
        guard width > 0 else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }

        let height = CodeBlockView.measureHeight(of: attachment.code, in: attachment.language)
        return CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }
}

private extension CodeBlockAttachmentProvider {
    enum Layout {
        static let fallbackSize = CGSize(width: 320, height: 80)
    }
    
    @MainActor
    static func makeBlockView(from content: CodeBlockContent, highlightStore: CodeBlockHighlightStore?) -> CodeBlockView {
        let view = CodeBlockView()
        view.configure(language: content.language, code: content.code)
        
        let highlighted = highlightStore?.highlightedResult(for: content.blockID)
        if let highlighted {
            view.apply(highlightedCode: highlighted)
        }
        
        highlightStore?.registerSink(view, for: content.blockID)
        
        return view
    }
}
