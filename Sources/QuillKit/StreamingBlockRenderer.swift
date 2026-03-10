import QuillCore
import UIKit

@MainActor
public final class StreamingBlockRenderer {
    public let stackView: UIStackView
    public private(set) var frozenViewCount: Int = 0

    public var tailConfiguration: TailConfiguration = .default

    private var tailDescriptor: TailDescriptor?
    private var tailBlock: Block?
    private weak var tailView: UIView?

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
        tailDescriptor = nil
        tailBlock = nil
        tailView = nil
    }

    public func append(blocks: [Block]) -> [UIView] {
        let nodes = FlowSegmentBuilder.build(from: blocks)
        return addViews(for: nodes[...])
    }

    public func update(blocks: [Block], frozenCount: Int) {
        precondition(Thread.isMainThread, "StreamingBlockRenderer.update must run on the main thread")

        clearTail()

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

    public func updateTail(block: Block?) {
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

    public func clearTail() {
        guard let tailView else {
            tailDescriptor = nil
            tailBlock = nil
            return
        }

        if let textFlowView = tailView as? TextFlowView {
            textFlowView.finishReveal()
        }

        stackView.removeArrangedSubview(tailView)
        tailView.removeFromSuperview()
        tailDescriptor = nil
        tailBlock = nil
        self.tailView = nil
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
}

private extension StreamingBlockRenderer {
    enum TailDescriptor: Equatable {
        case code(language: String?)
        case flow
        case table(columns: Int)
    }

    func addViews(for nodes: ArraySlice<RenderNode>) -> [UIView] {
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

            applyStructuralSpacing(for: view)
            views.append(view)
        }

        return views
    }

    func applyFlow(block: Block, to textFlowView: TextFlowView, animateText: Bool) {
        guard let attributedString = flowAttributedString(from: block) else { return }

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

    func flowAttributedString(from block: Block) -> NSAttributedString? {
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

    func replaceTail(with view: UIView, descriptor: TailDescriptor, sourceBlock: Block) {
        if let existingTail = tailView {
            stackView.removeArrangedSubview(existingTail)
            existingTail.removeFromSuperview()
        }

        stackView.addArrangedSubview(view)
        applyStructuralSpacing(for: view)
        tailView = view
        tailDescriptor = descriptor
        tailBlock = sourceBlock
    }

    func ensureTailIsLast() {
        guard let tailView,
              let currentIndex = stackView.arrangedSubviews.firstIndex(of: tailView),
              currentIndex != stackView.arrangedSubviews.count - 1
        else {
            return
        }

        stackView.removeArrangedSubview(tailView)
        stackView.addArrangedSubview(tailView)
        applyStructuralSpacing(for: tailView)
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

    func applyStructuralSpacing(for view: UIView) {
        if view is CodeBlockView || view is PlaceholderBlockView {
            stackView.setCustomSpacing(12, after: view)
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
            return isFlowPromotionCompatible(tail: tail, frozen: frozen)
        }
    }

    func isFlowPromotionCompatible(tail: Block, frozen: Block) -> Bool {
        guard let tailFlow = flowAttributedString(from: tail)?.string else { return false }
        guard let frozenFlow = flowAttributedString(from: frozen)?.string else { return false }

        let tailText = tailFlow.trimmingCharacters(in: .whitespacesAndNewlines)
        let frozenText = frozenFlow.trimmingCharacters(in: .whitespacesAndNewlines)
        guard tailText.isEmpty == false, frozenText.isEmpty == false else { return false }

        guard frozenText.hasPrefix(tailText) || tailText.hasPrefix(frozenText) else {
            return false
        }

        let overlapLength = min(tailText.count, frozenText.count)
        return overlapLength >= 12 || tailText == frozenText
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
               let attributed = flowAttributedString(from: frozenBlock) {
                textFlowView.configure(with: attributed)
            }
        }

        if let textFlowView = tailView as? TextFlowView {
            textFlowView.finishReveal()
        }
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
