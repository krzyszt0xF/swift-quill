import os
import QuillCore
import UIKit

@MainActor
final class StreamingBlockRenderer {
    var frozenViewCount: Int { frozenRenderer.frozenViewCount }
    var stateRegistry: [BlockState] { frozenRenderer.stateRegistry }

    var onLinkTap: ((URL) -> Void)?
    var tailConfiguration: TailConfiguration = .init(aggressiveness: .balanced)

    var renderedBlockViews: [UIView] {
        containerView.blockViews
    }

    var hostView: UIView {
        containerView
    }

    let containerView = BlockContainerView()
    private let nodeViewFactory: RenderNodeViewFactory
    private var frozenRenderer: FrozenBlockRenderer
    private var tailRenderer: TailRenderer

    init(
        frozenRenderer: FrozenBlockRenderer,
        nodeViewFactory: RenderNodeViewFactory,
        tailRenderer: TailRenderer) {
            self.nodeViewFactory = nodeViewFactory
            self.frozenRenderer = frozenRenderer
            self.tailRenderer = tailRenderer
        }

    func append(blocks: [Block]) -> [UIView] {
        let nodes = FlowSegmentBuilder.build(from: blocks)
        return addViews(for: nodes[...])
    }

    func clearTail() {
        tailRenderer.clearTail(containerView: containerView)
    }

    func invalidateHeightCaches() {
        containerView.invalidateAllHeightCaches()
        containerView.setNeedsLayout()
    }

    @discardableResult
    func promoteTailIfMatching(_ block: Block) -> UIView? {
        guard let tailView = tailRenderer.tailView,
              let tailBlock = tailRenderer.tailBlock,
              TailPromotionController.checkCompatibility(tail: tailBlock, frozen: block)
        else {
            return nil
        }

        TailPromotionController.prepareTailForPromotion(
            tailView: tailView,
            tailBlock: tailBlock,
            frozenBlock: block
        )

        tailRenderer.clearPromotedTail(containerView: containerView)
        
        return tailView
    }

    func rebindLinkTapHandlers() {
        for view in containerView.blockViews {
            FrozenBlockRenderer.applyLinkTapHandler(to: view, handler: onLinkTap)
        }

        if let tailView = tailRenderer.tailView {
            FrozenBlockRenderer.applyLinkTapHandler(to: tailView, handler: onLinkTap)
        }
    }

    func reset() {
        containerView.removeAllBlocks()
        frozenRenderer.reset()
        tailRenderer.reset()
    }

    func update(blocks: [Block], frozenCount: Int) {
        precondition(Thread.isMainThread, "StreamingBlockRenderer.update must run on the main thread")

        let signpostState = Self.signposter.beginInterval("update", id: Self.signposter.makeSignpostID())
        defer { Self.signposter.endInterval("update", signpostState) }

        clearTail()

        let nodes = FlowSegmentBuilder.build(from: blocks)
        let frozenNodeCount = FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: frozenCount)

        frozenRenderer.applyContainerUpdate(
            nodes: nodes,
            frozenNodeCount: frozenNodeCount,
            containerView: containerView,
            linkTapHandler: onLinkTap
        )
    }

    func updateTail(block: Block?) {
        let signpostState = Self.signposter.beginInterval("updateTail", id: Self.signposter.makeSignpostID())
        defer { Self.signposter.endInterval("updateTail", signpostState) }

        tailRenderer.updateTail(
            block: block,
            containerView: containerView,
            tailConfiguration: tailConfiguration,
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
            nodeViewFactory: .live,
            tailRenderer: .live
        )
    }
}

private extension StreamingBlockRenderer {
    func addViews(for nodes: ArraySlice<RenderNode>) -> [UIView] {
        var views: [UIView] = []
        let hasTailView = tailRenderer.tailView != nil
        var insertionIndex = max(0, containerView.blockViews.count - (hasTailView ? 1 : 0))

        for node in nodes {
            let view = nodeViewFactory.makeView(node)
            FrozenBlockRenderer.applyLinkTapHandler(to: view, handler: onLinkTap)

            if hasTailView {
                containerView.insertBlock(view, at: insertionIndex)
                insertionIndex += 1
            } else {
                containerView.insertBlock(view, at: containerView.blockViews.count)
            }

            views.append(view)
        }

        return views
    }
}
