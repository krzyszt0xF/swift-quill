import QuillCore
import UIKit

/// Incrementally renders streaming markdown using a frozen-prefix + mutable-tail strategy.
@MainActor
public final class StreamingBlockRenderer {
    public let stackView: UIStackView
    public private(set) var frozenViewCount: Int = 0

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

    public func append(blocks: [Block]) -> [UIView] {
        let nodes = FlowSegmentBuilder.build(from: blocks)
        return addViews(for: nodes[...])
    }

    public func update(blocks: [Block], frozenCount: Int) {
        precondition(Thread.isMainThread, "StreamingBlockRenderer.update must run on the main thread")

        let nodes = FlowSegmentBuilder.build(from: blocks)
        let frozenNodeCount = computeFrozenNodeCount(blocks: blocks, frozenCount: frozenCount)
        let existingCount = stackView.arrangedSubviews.count

        let promoteTo = min(frozenNodeCount, existingCount)
        if promoteTo > frozenViewCount {
            frozenViewCount = promoteTo
        }

        removeTailViews()
        _ = addViews(for: nodes[frozenViewCount...])
    }
}

private extension StreamingBlockRenderer {
    func addViews(for nodes: ArraySlice<RenderNode>) -> [UIView] {
        var views: [UIView] = []
        for node in nodes {
            let view = BlockRenderer.view(for: node)
            stackView.addArrangedSubview(view)
            if view is CodeBlockView || view is PlaceholderBlockView {
                stackView.setCustomSpacing(12, after: view)
            }
            views.append(view)
        }
        return views
    }

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
