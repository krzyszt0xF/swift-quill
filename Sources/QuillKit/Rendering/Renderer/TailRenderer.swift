import QuillCore
import UIKit

@MainActor
struct TailRenderer {
    enum TailDescriptor: Equatable {
        case code(language: String?)
        case flow
        case table(columns: Int)
    }

    private(set) var tailBlock: Block?
    private(set) var tailDescriptor: TailDescriptor?
    private(set) weak var tailView: UIView?
    private let nodeViewFactory: RenderNodeViewFactory

    init(nodeViewFactory: RenderNodeViewFactory) {
        self.nodeViewFactory = nodeViewFactory
    }

    mutating func clearTail(containerView: BlockContainerView) {
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

    mutating func updateTail(
        block: Block?,
        containerView: BlockContainerView,
        tailConfiguration: TailConfiguration,
        linkTapHandler: ((URL) -> Void)?
    ) {
        guard let block else {
            clearTail(containerView: containerView)
            return
        }

        let descriptor = Self.descriptor(for: block)

        switch descriptor {
        case .flow:
            if tailConfiguration.reuseFlowTailView,
               let existingTailView = tailView as? TextFlowView {
                Self.applyFlow(
                    block: block,
                    to: existingTailView,
                    animateText: tailConfiguration.animateFlowTailText,
                    tailConfiguration: tailConfiguration
                )
                containerView.invalidateBlockLayout(for: existingTailView)
                tailDescriptor = descriptor
                tailBlock = block
                ensureTailIsLast(containerView: containerView)
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
                ensureTailIsLast(containerView: containerView)
                return
            }

        case .table:
            if let existingTailView = tailView as? PlaceholderBlockView,
               case let .table(_, header, rows) = block {
                existingTailView.configureTable(header: header, rowCount: rows.count)
                containerView.invalidateBlockLayout(for: existingTailView)
                tailDescriptor = descriptor
                tailBlock = block
                ensureTailIsLast(containerView: containerView)
                return
            }

            if descriptor == tailDescriptor, tailView != nil {
                tailBlock = block
                ensureTailIsLast(containerView: containerView)
                return
            }
        }

        let view = makeTailView(for: block, animateFlowText: tailConfiguration.animateFlowTailText, tailConfiguration: tailConfiguration, linkTapHandler: linkTapHandler)
        replaceTail(with: view, descriptor: descriptor, sourceBlock: block, containerView: containerView)
    }

    mutating func reset() {
        tailDescriptor = nil
        tailBlock = nil
        tailView = nil
    }

    mutating func clearPromotedTail(containerView: BlockContainerView) {
        ensureTailIsLast(containerView: containerView)
        tailView = nil
        tailDescriptor = nil
        tailBlock = nil
    }
}

extension TailRenderer {
    static var live: Self {
        TailRenderer(nodeViewFactory: .live)
    }
}

// MARK: - View Creation

private extension TailRenderer {
    static func applyFlow(
        block: Block,
        to textFlowView: TextFlowView,
        animateText: Bool,
        tailConfiguration: TailConfiguration
    ) {
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

    static func descriptor(for block: Block) -> TailDescriptor {
        switch block {
        case let .codeBlock(language, _):
            return .code(language: language)
        case let .table(_, header, _):
            return .table(columns: header.cells.count)
        case .blockquote, .heading, .htmlBlock, .orderedList, .paragraph, .thematicBreak, .unorderedList:
            return .flow
        }
    }

    mutating func ensureTailIsLast(containerView: BlockContainerView) {
        guard let tailView,
              let currentIndex = containerView.blockViews.firstIndex(where: { $0 === tailView }),
              currentIndex != containerView.blockViews.count - 1
        else {
            return
        }
        containerView.removeBlock(at: currentIndex)
        containerView.insertBlock(tailView, at: containerView.blockViews.count)
    }

    static func makeFlowAttributedString(from block: Block) -> NSAttributedString? {
        let nodes = FlowSegmentBuilder.build(from: [block])
        guard case let .flow(segment) = nodes.first else {
            return nil
        }

        return AttributedStringBuilder.build(from: segment)
    }

    func makeTailView(
        for block: Block,
        animateFlowText: Bool,
        tailConfiguration: TailConfiguration,
        linkTapHandler: ((URL) -> Void)?
    ) -> UIView {
        let nodes = FlowSegmentBuilder.build(from: [block])
        guard let node = nodes.first else {
            return UIView()
        }

        let view = nodeViewFactory.makeView(node)
        FrozenBlockRenderer.applyLinkTapHandler(to: view, handler: linkTapHandler)
        if case .flow = node,
           let textFlowView = view as? TextFlowView {
            Self.applyFlow(block: block, to: textFlowView, animateText: animateFlowText, tailConfiguration: tailConfiguration)
        }

        return view
    }

    mutating func replaceTail(
        with view: UIView,
        descriptor: TailDescriptor,
        sourceBlock: Block,
        containerView: BlockContainerView
    ) {
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
