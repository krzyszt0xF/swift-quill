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

        let content = CodeBlockContent(from: attachment)
        let highlightStore = attachment.highlightStore
        let theme = attachment.theme
        view = executeIsolated {
            Self.makeBlockView(
                from: content,
                highlightStore: highlightStore,
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
        let fallbackSize = CGSize(width: 320, height: 80)
        let width = proposedLineFragment.width
        guard width > 0 else {
            return CGRect(origin: .zero, size: fallbackSize)
        }

        guard let attachment = textAttachment as? CodeBlockAttachment else {
            return CGRect(origin: .zero, size: fallbackSize)
        }

        let code = attachment.code
        let language = attachment.language
        let theme = attachment.theme
        let height = executeIsolated {
            CodeBlockView.measureHeight(
                of: code,
                in: language,
                theme: theme
            )
        }

        return CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }
}

private extension CodeBlockAttachmentProvider {
    static func makeBlockView(
        from content: CodeBlockContent,
        highlightStore: CodeBlockHighlightStore?,
        theme: QuillTheme
    ) -> CodeBlockView {
        let view = CodeBlockView(theme: theme)
        view.configure(language: content.language, code: content.code)
        highlightStore?.registerSink(view, for: content.blockID)

        let highlighted = highlightStore?.highlightedResult(for: content.blockID)
        if let highlighted {
            view.apply(highlightedCode: highlighted)
        }

        return view
    }
}
