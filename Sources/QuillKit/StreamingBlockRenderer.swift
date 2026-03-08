import QuillCore
import UIKit

/// Incrementally renders streaming markdown using a frozen-prefix + mutable-tail strategy.
@MainActor
public final class StreamingBlockRenderer {
    public let stackView: UIStackView
    private var frozenViewCount: Int = 0

    public init() {
        stackView = UIStackView()
        stackView.alignment = .fill
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
    }

    public func reset() {
        for view in stackView.arrangedSubviews.reversed() {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        frozenViewCount = 0
    }

    public func update(blocks: [Block], frozenCount: Int) {
        let nodes = FlowSegmentBuilder.build(from: blocks)
        let frozenNodeCount = computeFrozenNodeCount(blocks: blocks, frozenCount: frozenCount)
        let existingCount = stackView.arrangedSubviews.count

        let promoteTo = min(frozenNodeCount, existingCount)
        if promoteTo > frozenViewCount {
            frozenViewCount = promoteTo
        }

        removeTailViews()

        let isStreamingOpen = frozenCount < blocks.count

        for index in frozenViewCount..<nodes.count {
            let node = nodes[index]
            let isTailTip = index == nodes.count - 1 && isStreamingOpen
            let subview = createView(for: node, streaming: isTailTip)
            stackView.addArrangedSubview(subview)

            if subview is CodeBlockView || subview is PlaceholderBlockView {
                stackView.setCustomSpacing(12, after: subview)
            }
        }
    }
}

private extension StreamingBlockRenderer {
    func createView(for node: RenderNode, streaming: Bool) -> UIView {
        switch node {
        case let .codeBlock(language, code):
            let view = CodeBlockView()
            if streaming {
                view.configure(language: language, code: "")
                view.updateCode(code)
            } else {
                view.configure(language: language, code: code)
            }
            
            return view
        case let .flow(segment):
            let view = TextFlowView()
            if streaming {
                view.updateRawText(rawText(from: segment))
            } else {
                view.configure(with: AttributedStringBuilder.build(from: segment))
            }
            
            return view
        case let .image(_, title):
            return PlaceholderBlockView.image(title: title)
        case let .table(_, header, rows):
            return PlaceholderBlockView.table(header: header, rowCount: rows.count)
        }
    }
    
    func rawText(from segment: RenderNode.FlowSegment) -> String {
        segment.blocks.map { rawText(from: $0) }.joined(separator: "\n")
    }
    
    func rawText(from block: Block) -> String {
        switch block {
        case let .blockquote(children):
            return children.map { "> " + rawText(from: $0) }.joined(separator: "\n")
        case let .codeBlock(_, code):
            return code
        case let .heading(level, content):
            return String(repeating: "#", count: level) + " " + plainText(from: content)
        case let .htmlBlock(rawHTML):
            return rawHTML
        case let .orderedList(startIndex, items):
            return items.enumerated().map { index, item in
                "\(Int(startIndex) + index). " + item.children.map { rawText(from: $0) }.joined(separator: "\n")
            }.joined(separator: "\n")
        case let .paragraph(content):
            return plainText(from: content)
        case .table:
            return ""
        case .thematicBreak:
            return "---"
        case let .unorderedList(items):
            return items.map { item in
                "- " + item.children.map { rawText(from: $0) }.joined(separator: "\n")
            }.joined(separator: "\n")
        }
    }
    
    func plainText(from inlines: [Inline]) -> String {
        inlines.map { plainText(from: $0) }.joined()
    }
    
    func plainText(from inline: Inline) -> String {
        switch inline {
        case let .code(text):
            return text
        case let .emphasis(children):
            return plainText(from: children)
        case let .image(_, _, alt):
            return plainText(from: alt)
        case .inlineHTML:
            return ""
        case .lineBreak:
            return " "
        case let .link(_, children):
            return plainText(from: children)
        case let .strikethrough(children):
            return plainText(from: children)
        case let .strong(children):
            return plainText(from: children)
        case let .text(string):
            return string
        }
    }
}

private extension StreamingBlockRenderer {
    func computeFrozenNodeCount(blocks: [Block], frozenCount: Int) -> Int {
        guard frozenCount > 0 else { return 0 }

        var nodeCount = 0
        var blockIndex = 0
        var inFlowRun = false

        for block in blocks {
            if blockIndex >= frozenCount {
                if inFlowRun && block.isFlowContent {
                    break
                }
                break
            }

            if block.isFlowContent {
                if !inFlowRun {
                    inFlowRun = true
                    nodeCount += 1
                }
            } else {
                inFlowRun = false
                nodeCount += 1
            }

            blockIndex += 1
        }

        if inFlowRun && blockIndex < blocks.count && blocks[blockIndex].isFlowContent {
            nodeCount -= 1
        }

        return max(nodeCount, 0)
    }

    func removeTailViews() {
        let views = stackView.arrangedSubviews
        for index in stride(from: views.count - 1, through: frozenViewCount, by: -1) {
            let view = views[index]
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}
