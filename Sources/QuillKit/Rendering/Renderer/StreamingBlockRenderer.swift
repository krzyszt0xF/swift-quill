import os
import QuillCore
import UIKit

@MainActor
final class StreamingBlockRenderer {
    var frozenViewCount: Int { frozenRenderer.frozenViewCount }
    var stateRegistry: [BlockState] { frozenRenderer.stateRegistry }

    var onLinkTap: ((URL) -> Void)?

    var renderedBlockViews: [UIView] {
        containerView.blockViews
    }

    var hostView: UIView {
        containerView
    }

    let containerView = BlockContainerView()
    private let nodeViewFactory: RenderNodeViewFactory
    private var frozenRenderer: FrozenBlockRenderer

    init(
        frozenRenderer: FrozenBlockRenderer,
        nodeViewFactory: RenderNodeViewFactory) {
            self.nodeViewFactory = nodeViewFactory
            self.frozenRenderer = frozenRenderer
        }

    func append(blocks: [Block]) -> [UIView] {
        let nodes = FlowSegmentBuilder.build(from: blocks)
        return addViews(for: nodes[...])
    }

    func invalidateHeightCaches() {
        containerView.invalidateAllHeightCaches()
        containerView.setNeedsLayout()
    }

    func rebindLinkTapHandlers() {
        for view in containerView.blockViews {
            FrozenBlockRenderer.applyLinkTapHandler(to: view, handler: onLinkTap)
        }
    }

    func reset() {
        containerView.removeAllBlocks()
        frozenRenderer.reset()
    }

    func update(blocks: [Block], frozenCount: Int) {
        precondition(Thread.isMainThread, "StreamingBlockRenderer.update must run on the main thread")

        let signpostState = Self.signposter.beginInterval("update", id: Self.signposter.makeSignpostID())
        defer { Self.signposter.endInterval("update", signpostState) }

        let nodes = FlowSegmentBuilder.build(from: blocks)
        let frozenNodeCount = FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: frozenCount)

        frozenRenderer.applyContainerUpdate(
            nodes: nodes,
            frozenNodeCount: frozenNodeCount,
            containerView: containerView,
            linkTapHandler: onLinkTap
        )
    }

    private static let signposter = OSSignposter(
        subsystem: "com.quill.renderer",
        category: "Performance"
    )
}

extension StreamingBlockRenderer {
    static var live: StreamingBlockRenderer {
        StreamingBlockRenderer(
            frozenRenderer: .live,
            nodeViewFactory: .live
        )
    }
}

private extension StreamingBlockRenderer {
    func addViews(for nodes: ArraySlice<RenderNode>) -> [UIView] {
        var views: [UIView] = []

        for node in nodes {
            let view = nodeViewFactory.makeView(node)
            FrozenBlockRenderer.applyLinkTapHandler(to: view, handler: onLinkTap)
            containerView.insertBlock(view, at: containerView.blockViews.count)

            views.append(view)
        }

        return views
    }
}
