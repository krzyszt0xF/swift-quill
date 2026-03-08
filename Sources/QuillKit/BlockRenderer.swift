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
    static func placeholder(_ text: String) -> UIView {
        let label = UILabel()
        label.backgroundColor = UIColor.systemGray6
        label.font = .systemFont(ofSize: 14)
        label.text = text
        label.textAlignment = .center
        label.textColor = .secondaryLabel

        return label
    }

    static func view(for node: RenderNode) -> UIView {
        switch node {
        case .codeBlock:
            return placeholder("Code block (Phase 4)")
        case let .flow(segment):
            let view = TextFlowView()
            view.configure(with: AttributedStringBuilder.build(from: segment))
            return view
        case .image:
            return placeholder("Image (Phase 4)")
        case .table:
            return placeholder("Table (Phase 4)")
        }
    }
}