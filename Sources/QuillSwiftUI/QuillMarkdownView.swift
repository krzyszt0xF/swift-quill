import QuillKit
import SwiftUI

/// Static markdown rendering view backed by QuillView.
public struct QuillMarkdownView: UIViewRepresentable {
    let markdown: String

    public init(markdown: String) {
        self.markdown = markdown
    }

    public func makeUIView(context: Context) -> QuillView {
        let view = QuillView()
        view.markdown = markdown
        return view
    }

    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: QuillView,
        context: Context
    ) -> CGSize? {
        fittedSize(for: uiView, proposal: proposal)
    }

    public func updateUIView(_ uiView: QuillView, context: Context) {
        guard uiView.markdown != markdown else { return }
        uiView.markdown = markdown
    }
}
