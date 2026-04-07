import UIKit

@MainActor
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

        view = Self.makeBlockView(
            from: CodeBlockContent(from: attachment),
            highlightStore: attachment.highlightStore,
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
        guard let attachment = textAttachment as? CodeBlockAttachment else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }

        let width = proposedLineFragment.width
        guard width > 0 else {
            return CGRect(origin: .zero, size: Layout.fallbackSize)
        }

        let height = CodeBlockView.measureHeight(
            of: attachment.code,
            in: attachment.language,
            theme: attachment.theme
        )
        return CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }
}

private extension CodeBlockAttachmentProvider {
    enum Layout {
        static let fallbackSize = CGSize(width: 320, height: 80)
    }

    static func makeBlockView(
        from content: CodeBlockContent,
        highlightStore: CodeBlockHighlightStore?,
        theme: QuillTheme
    ) -> CodeBlockView {
        let view = CodeBlockView(theme: theme)
        view.configure(language: content.language, code: content.code)

        let highlighted = highlightStore?.highlightedResult(for: content.blockID)
        if let highlighted {
            view.apply(highlightedCode: highlighted)
        }

        highlightStore?.registerSink(view, for: content.blockID)

        return view
    }
}
