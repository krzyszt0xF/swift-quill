import os
import QuillCore
import UIKit

@MainActor
final class StreamingBlockRenderer {
    private(set) var frozenViewCount: Int = 0
    private(set) var stateRegistry: [BlockState] = []

    var tailConfiguration: TailConfiguration = .default

    var renderedBlockViews: [UIView] {
        containerView.blockViews
    }

    var hostView: UIView {
        containerView
    }

    let containerView = BlockContainerView()
    private var tailBlock: Block?
    private var tailDescriptor: TailDescriptor?
    private weak var tailView: UIView?

    func append(blocks: [Block]) -> [UIView] {
        let nodes = FlowSegmentBuilder.build(from: blocks)
        return addViews(for: nodes[...])
    }

    func clearTail() {
        guard let tailView else {
            tailDescriptor = nil
            tailBlock = nil
            return
        }

        if let textFlowView = tailView as? TextFlowView {
            textFlowView.finishReveal()
        }

        if let index = containerView.blockViews.firstIndex(where: { $0 === tailView }) {
            containerView.removeBlock(at: index)
        }

        tailDescriptor = nil
        tailBlock = nil
        self.tailView = nil
    }

    func invalidateHeightCaches() {
        containerView.invalidateAllHeightCaches()
        containerView.setNeedsLayout()
    }

    @discardableResult
    func promoteTailIfMatching(_ block: Block) -> UIView? {
        guard let tailView,
              let tailBlock,
              isPromotionCompatible(tail: tailBlock, frozen: block)
        else {
            return nil
        }

        prepareTailForPromotion(tailView: tailView, tailBlock: tailBlock, frozenBlock: block)

        ensureTailIsLast()
        self.tailView = nil
        tailDescriptor = nil
        self.tailBlock = nil
        return tailView
    }

    func reset() {
        containerView.removeAllBlocks()
        frozenViewCount = 0
        stateRegistry.removeAll()
        tailDescriptor = nil
        tailBlock = nil
        tailView = nil
    }

    func update(blocks: [Block], frozenCount: Int) {
        precondition(Thread.isMainThread, "StreamingBlockRenderer.update must run on the main thread")

        let signpostState = Self.signposter.beginInterval("update", id: Self.signposter.makeSignpostID())
        defer { Self.signposter.endInterval("update", signpostState) }

        clearTail()

        let nodes = FlowSegmentBuilder.build(from: blocks)
        let frozenNodeCount = FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: frozenCount)

        applyContainerUpdate(nodes: nodes, frozenNodeCount: frozenNodeCount)
    }

    func updateTail(block: Block?) {
        let signpostState = Self.signposter.beginInterval("updateTail", id: Self.signposter.makeSignpostID())
        defer { Self.signposter.endInterval("updateTail", signpostState) }

        guard let block else {
            clearTail()
            return
        }

        let descriptor = descriptor(for: block)

        switch descriptor {
        case .flow:
            if tailConfiguration.reuseFlowTailView,
               let existingTailView = tailView as? TextFlowView {
                applyFlow(
                    block: block,
                    to: existingTailView,
                    animateText: tailConfiguration.animateFlowTailText
                )
                containerView.invalidateBlockLayout(for: existingTailView)
                tailDescriptor = descriptor
                tailBlock = block
                ensureTailIsLast()
                return
            }

        case let .code(language):
            if tailConfiguration.reuseCodeTailView,
               let existingTailView = tailView as? CodeBlockView,
               existingTailView.currentLanguage == language,
               case let .codeBlock(_, code) = block {
                existingTailView.updateCode(code)
                containerView.invalidateBlockLayout(for: existingTailView)
                tailDescriptor = descriptor
                tailBlock = block
                ensureTailIsLast()
                return
            }

        case .table:
            if let existingTailView = tailView as? PlaceholderBlockView,
               case let .table(_, header, rows) = block {
                existingTailView.configureTable(header: header, rowCount: rows.count)
                containerView.invalidateBlockLayout(for: existingTailView)
                tailDescriptor = descriptor
                tailBlock = block
                ensureTailIsLast()
                return
            }

            if descriptor == tailDescriptor, tailView != nil {
                tailBlock = block
                ensureTailIsLast()
                return
            }
        }

        let view = makeTailView(for: block, animateFlowText: tailConfiguration.animateFlowTailText)
        replaceTail(with: view, descriptor: descriptor, sourceBlock: block)
    }

    private static let signposter = OSSignposter(
        subsystem: "com.quill.renderer",
        category: "Performance"
    )
}

// MARK: - Container Update

private extension StreamingBlockRenderer {
    func applyContainerUpdate(nodes: [RenderNode], frozenNodeCount: Int) {
        if frozenNodeCount > frozenViewCount {
            frozenViewCount = frozenNodeCount
        }

        let newStates = buildNewStates(nodes: nodes, frozenNodeCount: frozenViewCount)
        let oldStates = stateRegistry

        let oldIDs = oldStates.map(\.id)
        let newIDs = newStates.map(\.id)
        let diff = newIDs.difference(from: oldIDs)

        var removals: [(offset: Int, id: UUID)] = []
        var insertions: [(offset: Int, id: UUID)] = []

        for change in diff {
            switch change {
            case let .insert(offset, id, _):
                insertions.append((offset: offset, id: id))
            case let .remove(offset, id, _):
                removals.append((offset: offset, id: id))
            }
        }

        for removal in removals.sorted(by: { $0.offset > $1.offset }) {
            containerView.removeBlock(at: removal.offset)
        }

        for insertion in insertions.sorted(by: { $0.offset < $1.offset }) {
            let state = newStates[insertion.offset]
            let view = RenderNodeViewFactory.view(for: state.node)
            containerView.insertBlock(view, at: min(insertion.offset, containerView.blockViews.count))
        }

        let oldNodeByID = Dictionary(oldStates.map { ($0.id, $0.node) }, uniquingKeysWith: { _, new in new })
        for (index, state) in newStates.enumerated() {
            if let oldNode = oldNodeByID[state.id], oldNode != state.node {
                let view = RenderNodeViewFactory.view(for: state.node)
                containerView.updateBlock(at: index, with: view)
            }
        }

        stateRegistry = newStates
    }

    func buildNewStates(nodes: [RenderNode], frozenNodeCount: Int) -> [BlockState] {
        var newStates: [BlockState] = []

        for (index, node) in nodes.enumerated() {
            let isFrozen = index < frozenNodeCount

            if isFrozen, index < stateRegistry.count {
                let existingState = stateRegistry[index]
                newStates.append(BlockState(
                    id: existingState.id,
                    isFrozen: true,
                    node: node
                ))
            } else {
                newStates.append(BlockState(
                    id: UUID(),
                    isFrozen: isFrozen,
                    node: node
                ))
            }
        }

        return newStates
    }
}

// MARK: - View Lifecycle

private extension StreamingBlockRenderer {
    func addViews(for nodes: ArraySlice<RenderNode>) -> [UIView] {
        var views: [UIView] = []
        let hasTailView = tailView != nil
        var insertionIndex = max(0, containerView.blockViews.count - (hasTailView ? 1 : 0))

        for node in nodes {
            let view = RenderNodeViewFactory.view(for: node)

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

// MARK: - Tail Management

private extension StreamingBlockRenderer {
    enum TailDescriptor: Equatable {
        case code(language: String?)
        case flow
        case table(columns: Int)
    }

    func applyFlow(block: Block, to textFlowView: TextFlowView, animateText: Bool) {
        guard let attributedString = makeFlowAttributedString(from: block) else { return }

        if animateText {
            textFlowView.configureStreaming(
                with: attributedString,
                charsPerStep: tailConfiguration.flowTailCharsPerStep,
                baseDuration: tailConfiguration.flowTailBaseDuration,
                commaPause: tailConfiguration.flowTailCommaPause,
                sentencePause: tailConfiguration.flowTailSentencePause, jitterMax: tailConfiguration.flowTailJitterMax,
                startBufferCharacters: tailConfiguration.flowTailStartBufferCharacters,
                maxStartDelay: tailConfiguration.flowTailMaxStartDelay,
                idleTimeout: tailConfiguration.flowTailIdleTimeout,
                revealInitialAlpha: tailConfiguration.flowTailRevealInitialAlpha,
                revealFadeDuration: tailConfiguration.flowTailRevealFadeDuration
            )
        } else {
            textFlowView.configure(with: attributedString)
        }
    }

    func checkFlowPromotionCompatibility(tail: Block, frozen: Block) -> Bool {
        guard let tailFlow = makeFlowAttributedString(from: tail)?.string,
              let frozenFlow = makeFlowAttributedString(from: frozen)?.string else { return false }

        let tailText = tailFlow.trimmingCharacters(in: .whitespacesAndNewlines)
        let frozenText = frozenFlow.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tailText.isEmpty == false, frozenText.isEmpty == false else { return false }

        guard frozenText.hasPrefix(tailText) || tailText.hasPrefix(frozenText) else {
            return false
        }

        let overlapLength = min(tailText.count, frozenText.count)
        return overlapLength >= 12 || tailText == frozenText
    }

    func descriptor(for block: Block) -> TailDescriptor {
        switch block {
        case let .codeBlock(language, _):
            return .code(language: language)
        case let .table(_, header, _):
            return .table(columns: header.cells.count)
        case .blockquote, .heading, .htmlBlock, .orderedList, .paragraph, .thematicBreak, .unorderedList:
            return .flow
        }
    }

    func ensureTailIsLast() {
        guard let tailView,
              let currentIndex = containerView.blockViews.firstIndex(where: { $0 === tailView }),
              currentIndex != containerView.blockViews.count - 1
        else {
            return
        }
        containerView.removeBlock(at: currentIndex)
        containerView.insertBlock(tailView, at: containerView.blockViews.count)
    }

    func isPromotionCompatible(tail: Block, frozen: Block) -> Bool {
        if tail == frozen {
            return true
        }

        switch (tail, frozen) {
        case let (.codeBlock(tailLanguage, tailCode), .codeBlock(frozenLanguage, frozenCode)):
            return tailLanguage == frozenLanguage
                && (frozenCode.hasPrefix(tailCode) || tailCode.hasPrefix(frozenCode))
        case let (.table(_, tailHeader, tailRows), .table(_, frozenHeader, frozenRows)):
            return tailHeader.cells.count == frozenHeader.cells.count
                && frozenRows.count >= tailRows.count
        default:
            return checkFlowPromotionCompatibility(tail: tail, frozen: frozen)
        }
    }

    func makeFlowAttributedString(from block: Block) -> NSAttributedString? {
        let nodes = FlowSegmentBuilder.build(from: [block])
        guard case let .flow(segment) = nodes.first else {
            return nil
        }

        return AttributedStringBuilder.build(from: segment)
    }

    func makeTailView(for block: Block, animateFlowText: Bool) -> UIView {
        let nodes = FlowSegmentBuilder.build(from: [block])
        guard let node = nodes.first else {
            return UIView()
        }

        let view = RenderNodeViewFactory.view(for: node)
        if case .flow = node,
           let textFlowView = view as? TextFlowView {
            applyFlow(block: block, to: textFlowView, animateText: animateFlowText)
        }

        return view
    }

    func prepareTailForPromotion(
        tailView: UIView,
        tailBlock: Block,
        frozenBlock: Block
    ) {
        switch (tailBlock, frozenBlock) {
        case (.codeBlock, let .codeBlock(_, frozenCode)):
            if let codeBlockView = tailView as? CodeBlockView {
                codeBlockView.updateCode(frozenCode)
            }
        case let (.table(_, _, _), .table(_, header, rows)):
            if let placeholder = tailView as? PlaceholderBlockView {
                placeholder.configureTable(header: header, rowCount: rows.count)
            }
        default:
            if let textFlowView = tailView as? TextFlowView,
               let attributed = makeFlowAttributedString(from: frozenBlock) {
                textFlowView.configure(with: attributed)
            }
        }

        if let textFlowView = tailView as? TextFlowView {
            textFlowView.finishReveal()
        }
    }

    func replaceTail(with view: UIView, descriptor: TailDescriptor, sourceBlock: Block) {
        if let existingTail = tailView {
            if let index = containerView.blockViews.firstIndex(where: { $0 === existingTail }) {
                containerView.removeBlock(at: index)
            }
        }

        containerView.insertBlock(view, at: containerView.blockViews.count)

        tailView = view
        tailDescriptor = descriptor
        tailBlock = sourceBlock
    }
}
