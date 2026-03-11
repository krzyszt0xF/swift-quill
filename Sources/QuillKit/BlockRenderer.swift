import QuillCore
import UIKit

@MainActor
enum BlockRenderer {
    static func render(_ nodes: [RenderNode]) -> UIView {
        let stack = UIStackView()
        stack.alignment = .fill
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        for node in nodes {
            let subview = view(for: node)
            stack.addArrangedSubview(subview)

            if subview is CodeBlockView || subview is PlaceholderBlockView {
                stack.setCustomSpacing(12, after: subview)
            }
        }

        return stack
    }

    static func render(markdown: String, parser: MarkdownParser = .live) -> UIView {
        let blocks = parser.parse(markdown)
        let nodes = FlowSegmentBuilder.build(from: blocks)

        return render(nodes)
    }

    static func view(for node: RenderNode) -> UIView {
        switch node {
        case let .codeBlock(language, code):
            let view = CodeBlockView()
            view.configure(language: language, code: code)
            return view
        case let .flow(segment):
            let view = TextFlowView()
            view.configure(with: AttributedStringBuilder.build(from: segment))
            return view
        case let .image(_, title):
            return PlaceholderBlockView.image(title: title)
        case let .table(_, header, rows):
            return PlaceholderBlockView.table(header: header, rowCount: rows.count)
        }
    }
}
