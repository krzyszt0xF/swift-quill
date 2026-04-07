import QuillKit
import SwiftUI

/// Static markdown rendering view backed by QuillView.
public struct QuillMarkdownView: UIViewRepresentable {
    let configuration: QuillConfiguration
    let markdown: String
    let linkTapHandler: ((URL) -> Void)?

    public init(
        markdown: String,
        configuration: QuillConfiguration = .default
    ) {
        self.init(
            markdown: markdown,
            configuration: configuration,
            linkTapHandler: nil
        )
    }

    private init(
        markdown: String,
        configuration: QuillConfiguration,
        linkTapHandler: ((URL) -> Void)?
    ) {
        self.configuration = configuration
        self.markdown = markdown
        self.linkTapHandler = linkTapHandler
    }

    public func makeUIView(context: Context) -> QuillView {
        let view = QuillView(configuration: configuration)
        applyConfiguration(
            to: view,
            imageLoader: context.environment.quillImageLoader,
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
            syntaxHighlighter: context.environment.quillSyntaxHighlighter
        )
    }
}

public extension QuillMarkdownView {
    func onQuillLinkTap(_ handler: @escaping (URL) -> Void) -> Self {
        Self(
            markdown: markdown,
            configuration: configuration,
            linkTapHandler: handler
        )
    }
}

extension QuillMarkdownView {
    func applyConfiguration(
        to view: QuillView,
        imageLoader: (any ImageLoading)? = nil,
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
