import QuillKit
import SwiftUI

/// Static markdown rendering view backed by QuillView.
public struct QuillMarkdownView: UIViewRepresentable {
    let configuration: QuillConfiguration
    let markdown: String

    public init(
        markdown: String,
        configuration: QuillConfiguration = .default
    ) {
        self.configuration = configuration
        self.markdown = markdown
    }

    public func makeUIView(context: Context) -> QuillView {
        let view = QuillView(configuration: configuration)
        applyConfiguration(
            to: view,
            imageLoader: context.environment.quillImageLoader,
            linkTapHandler: context.environment.quillLinkTapHandler,
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
            imageLoader: context.environment.quillImageLoader,
            linkTapHandler: context.environment.quillLinkTapHandler,
            syntaxHighlighter: context.environment.quillSyntaxHighlighter
        )
    }
}

extension QuillMarkdownView {
    func applyConfiguration(
        to view: QuillView,
        imageLoader: (any ImageLoading)? = nil,
        linkTapHandler: (@Sendable (URL) -> Void)? = nil,
        syntaxHighlighter: (any SyntaxHighlighting)? = nil
    ) {
        view.imageLoader = imageLoader
        view.onLinkSelection = linkTapHandler
        view.syntaxHighlighter = syntaxHighlighter
        view.configuration = configuration
        guard view.markdown != markdown else { return }

        view.markdown = markdown
    }
}
