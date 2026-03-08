import QuillCore
import UIKit

/// Assembles RenderNodes into a vertical UIView hierarchy.
public enum BlockRenderer {
    public static func render(_ nodes: [RenderNode]) -> UIView {
        let stack = UIStackView()
        stack.alignment = .fill
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        for node in nodes {
            stack.addArrangedSubview(view(for: node))
        }

        return stack
    }

    public static func render(markdown: String, parser: MarkdownParser = .live) -> UIView {
        let blocks = parser.parse(markdown)
        let nodes = FlowSegmentBuilder.build(from: blocks)
        
        return render(nodes)
    }
}

private extension BlockRenderer {
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