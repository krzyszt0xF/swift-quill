import os
import QuillCore
import UIKit

@MainActor
final class StreamingBlockRenderer {
    enum Backend {
        case containerView
        case stackView
    }

    let backend: Backend
    private(set) var frozenViewCount: Int = 0
    private(set) var stateRegistry: [BlockState] = []

    var tailConfiguration: TailConfiguration = .default

    var arrangedBlockViews: [UIView] {
        switch storage {
        case let .containerView(view): return view.blockViews
        case let .stackView(view): return view.arrangedSubviews
        }
    }

    var hostView: UIView {
        switch storage {
        case let .containerView(view): return view
        case let .stackView(view): return view
        }
    }

    private let storage: BackendStorage
    private var tailBlock: Block?
    private var tailDescriptor: TailDescriptor?
    private weak var tailView: UIView?
    private var viewRegistry: [UUID: UIView] = [:]

    init(backend: Backend = .stackView) {
        self.backend = backend

        switch backend {
        case .containerView:
            storage = .containerView(BlockContainerView())
        case .stackView:
            let stackView = UIStackView()
            stackView.alignment = .fill
            stackView.axis = .vertical
            stackView.spacing = 0
            stackView.translatesAutoresizingMaskIntoConstraints = false
            storage = .stackView(stackView)
        }
    }

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

        switch storage {
        case let .containerView(containerView):
            if let index = containerView.blockViews.firstIndex(where: { $0 === tailView }) {
                containerView.removeBlock(at: index)
            }
        case let .stackView(stackView):
            stackView.removeArrangedSubview(tailView)
            tailView.removeFromSuperview()
        }

        tailDescriptor = nil
        tailBlock = nil
        self.tailView = nil
    }

    func invalidateHeightCaches() {
        switch storage {
        case let .containerView(containerView):
            containerView.invalidateAllHeightCaches()
        case .stackView:
            break
        }
        hostView.setNeedsLayout()
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
        switch storage {
        case let .containerView(containerView):
            containerView.removeAllBlocks()
        case let .stackView(stackView):
            for view in stackView.arrangedSubviews.reversed() {
                stackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }

        frozenViewCount = 0
        stateRegistry.removeAll()
        viewRegistry.removeAll()
        tailDescriptor = nil
        tailBlock = nil
        tailView = nil
    }

    func runBenchmarkRelayoutPass() {
        switch storage {
        case let .containerView(containerView):
            containerView.invalidateAllHeightCaches()
            containerView.relayoutForBenchmarkPass()
        case let .stackView(stackView):
            stackView.setNeedsLayout()
            stackView.layoutIfNeeded()
        }
    }

    func update(blocks: [Block], frozenCount: Int) {
        precondition(Thread.isMainThread, "StreamingBlockRenderer.update must run on the main thread")

        let signpostState = Self.signposter.beginInterval("update", id: Self.signposter.makeSignpostID())
        defer { Self.signposter.endInterval("update", signpostState) }

        clearTail()

        let nodes = FlowSegmentBuilder.build(from: blocks)
        let frozenNodeCount = FlowSegmentBuilder.frozenNodeCount(blocks: blocks, frozenBlockCount: frozenCount)

        switch backend {
        case .containerView:
            applyContainerUpdate(nodes: nodes, frozenNodeCount: frozenNodeCount)
        case .stackView:
            applyStackViewUpdate(nodes: nodes, frozenNodeCount: frozenNodeCount)
        }
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
                tailDescriptor = descriptor
                tailBlock = block
                ensureTailIsLast()
                return
            }

        case .table:
            if let existingTailView = tailView as? PlaceholderBlockView,
               case let .table(_, header, rows) = block {
                existingTailView.configureTable(header: header, rowCount: rows.count)
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

    private enum BackendStorage {
        case containerView(BlockContainerView)
        case stackView(UIStackView)
    }

    private static let signposter = OSSignposter(
        subsystem: "com.quill.renderer",
        category: "Performance"
    )

    var containerView: BlockContainerView {
        guard case let .containerView(view) = storage else {
            assertionFailure("Accessed containerView on .stackView backend")
            return BlockContainerView()
        }
        return view
    }

    var stackView: UIStackView {
        guard case let .stackView(view) = storage else {
            assertionFailure("Accessed stackView on .containerView backend")
            return UIStackView()
        }
        return view
    }
}

// MARK: - Backend Update Strategies

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
            viewRegistry.removeValue(forKey: removal.id)
        }

        for insertion in insertions.sorted(by: { $0.offset < $1.offset }) {
            let state = newStates[insertion.offset]
            let view = BlockRenderer.view(for: state.node)
            viewRegistry[state.id] = view
            containerView.insertBlock(view, at: min(insertion.offset, containerView.blockViews.count))
        }

        let oldNodeByID = Dictionary(oldStates.map { ($0.id, $0.node) }, uniquingKeysWith: { _, new in new })
        for (index, state) in newStates.enumerated() {
            if let oldNode = oldNodeByID[state.id], oldNode != state.node {
                let view = BlockRenderer.view(for: state.node)
                viewRegistry[state.id] = view
                containerView.updateBlock(at: index, with: view)
            }
        }

        stateRegistry = newStates
    }

    func applyStackViewUpdate(nodes: [RenderNode], frozenNodeCount: Int) {
        let existingCount = stackView.arrangedSubviews.count

        let promoteTo = min(frozenNodeCount, existingCount)
        if promoteTo > frozenViewCount {
            frozenViewCount = promoteTo
        }

        removeTailViews()
        _ = addViews(for: nodes[frozenViewCount...])
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
        switch storage {
        case let .containerView(containerView):
            return addViewsToContainer(containerView, for: nodes)
        case let .stackView(stackView):
            return addViewsToStackView(stackView, for: nodes)
        }
    }

    func addViewsToContainer(
        _ containerView: BlockContainerView,
        for nodes: ArraySlice<RenderNode>
    ) -> [UIView] {
        var views: [UIView] = []
        let hasTailView = tailView != nil
        var insertionIndex = max(0, containerView.blockViews.count - (hasTailView ? 1 : 0))

        for node in nodes {
            let view = BlockRenderer.view(for: node)

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

    func addViewsToStackView(
        _ stackView: UIStackView,
        for nodes: ArraySlice<RenderNode>
    ) -> [UIView] {
        var views: [UIView] = []
        let hasTailView = tailView != nil
        var insertionIndex = max(0, stackView.arrangedSubviews.count - (hasTailView ? 1 : 0))

        for node in nodes {
            let view = BlockRenderer.view(for: node)

            if hasTailView {
                stackView.insertArrangedSubview(view, at: insertionIndex)
                insertionIndex += 1
            } else {
                stackView.addArrangedSubview(view)
            }

            applyStackViewSpacing(for: view)
            views.append(view)
        }

        return views
    }

    func applyStackViewSpacing(for view: UIView) {
        if view is CodeBlockView || view is PlaceholderBlockView {
            stackView.setCustomSpacing(12, after: view)
        }
    }

    func removeTailViews() {
        let views = stackView.arrangedSubviews
        let hasTailView = tailView != nil
        let upperBound = views.count - (hasTailView ? 2 : 1)
        guard upperBound >= frozenViewCount else { return }

        for index in stride(from: upperBound, through: frozenViewCount, by: -1) {
            let view = views[index]
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
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
                sentencePause: tailConfiguration.flowTailSentencePause,
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
        guard let tailView else { return }

        switch storage {
        case let .containerView(containerView):
            guard let currentIndex = containerView.blockViews.firstIndex(where: { $0 === tailView }),
                  currentIndex != containerView.blockViews.count - 1
            else {
                return
            }
            containerView.removeBlock(at: currentIndex)
            containerView.insertBlock(tailView, at: containerView.blockViews.count)

        case let .stackView(stackView):
            guard let currentIndex = stackView.arrangedSubviews.firstIndex(of: tailView),
                  currentIndex != stackView.arrangedSubviews.count - 1
            else {
                return
            }
            stackView.removeArrangedSubview(tailView)
            stackView.addArrangedSubview(tailView)
            applyStackViewSpacing(for: tailView)
        }
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

        let view = BlockRenderer.view(for: node)
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
            switch storage {
            case let .containerView(containerView):
                if let index = containerView.blockViews.firstIndex(where: { $0 === existingTail }) {
                    containerView.removeBlock(at: index)
                }
            case let .stackView(stackView):
                stackView.removeArrangedSubview(existingTail)
                existingTail.removeFromSuperview()
            }
        }

        switch storage {
        case let .containerView(containerView):
            containerView.insertBlock(view, at: containerView.blockViews.count)
        case let .stackView(stackView):
            stackView.addArrangedSubview(view)
            applyStackViewSpacing(for: view)
        }

        tailView = view
        tailDescriptor = descriptor
        tailBlock = sourceBlock
    }
}
