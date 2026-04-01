import QuillKit
import SwiftUI

/// Static markdown rendering view backed by QuillView.
public struct QuillMarkdownView: UIViewRepresentable {
    let markdown: String
    let linkTapHandler: ((URL) -> Void)?

    public init(markdown: String) {
        self.init(markdown: markdown, linkTapHandler: nil)
    }

    private init(markdown: String, linkTapHandler: ((URL) -> Void)?) {
        self.markdown = markdown
        self.linkTapHandler = linkTapHandler
    }

    public func makeUIView(context: Context) -> QuillView {
        let view = QuillView()
        applyConfiguration(
            to: view,
            syntaxHighlighter: context.environment.quillSyntaxHighlighter
        )
        
        return view
    }
    
    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: QuillView,
        context: Context) -> CGSize? {
            uiView.calculateFittedSize(for: proposal)
        }
    
    public func updateUIView(_ uiView: QuillView, context: Context) {
        applyConfiguration(
            to: uiView,
            syntaxHighlighter: context.environment.quillSyntaxHighlighter
        )
    }
}

public extension QuillMarkdownView {
    func onQuillLinkTap(_ handler: @escaping (URL) -> Void) -> Self {
        Self(markdown: markdown, linkTapHandler: handler)
    }
}

extension QuillMarkdownView {
    func applyConfiguration(
        to view: QuillView,
        syntaxHighlighter: (any SyntaxHighlighting)? = nil
    ) {
        view.onLinkSelection = linkTapHandler
        view.syntaxHighlighter = syntaxHighlighter
        guard view.markdown != markdown else { return }

        view.markdown = markdown
    }
}
