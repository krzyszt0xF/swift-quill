import QuillCore
import UIKit

@MainActor
final class DocumentRenderer {
    let textView: DocumentTextView
    var onTailRevealProgress: (() -> Void)? {
        didSet { tailRevealEngine.onProgress = onTailRevealProgress }
    }

    var blockIndexer = DocumentBlockIndexer()
    var highlightCoordinator: HighlightCoordinator
    var renderState = RenderState()
    let tailAnimator = TailAnimator()
    var tailRevealPolicy: TailRevealPolicy?
    lazy var tailRevealEngine = TailRevealEngine { [weak self] batch in
        self?.appendTailRevealBatch(batch) ?? false
    }

    init(
        textView: DocumentTextView,
        highlightCoordinator: HighlightCoordinator
    ) {
        self.textView = textView
        self.highlightCoordinator = highlightCoordinator
        tailRevealEngine.advancePresentation = { [weak self] timestamp in
            self?.advanceTailFade(timestamp: timestamp) ?? false
        }
        tailRevealEngine.hasPresentationWork = { [weak self] in
            self?.tailAnimator.hasActiveSegments ?? false
        }
    }

    func applyTailRevealPolicy(_ policy: TailRevealPolicy) {
        tailRevealPolicy = policy
    }

    func cancelStreaming() {
        tailRevealEngine.cancel()
        tailAnimator.cancel()
        highlightCoordinator.cancelAll()
        renderState.resetSmoothedTailStart()
    }

    @discardableResult
    func render(blocks: [BlockNode], frozenCount: Int) -> RenderOutcome {
        let fragments = AttributedStringBuilder.buildRenderFragments(
            from: blocks,
            frozenCount: frozenCount,
            highlightStore: highlightCoordinator
        )
        let previousFrozenCount = renderState.frozenBlockCount
        let renderOutcome = makeRenderOutcome(
            from: fragments,
            frozenCount: frozenCount,
            previousFrozenCount: previousFrozenCount,
            blockCount: blocks.count
        )

        scheduleHighlightsForNewlyFrozenCodeBlocks(
            blocks: blocks,
            previousFrozenCount: previousFrozenCount,
            newFrozenCount: frozenCount
        )

        return renderOutcome
    }

    func reset() {
        cancelStreaming()
        blockIndexer.removeAll()
        highlightCoordinator.cancelAll()
        renderState.reset()

        guard let contentStorage = textView.contentStorage,
              let attributedString = contentStorage.attributedString,
              attributedString.length > 0
        else { return }

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: attributedString.length),
                with: ""
            )
        }
        textView.handleDocumentContentChange()
    }

    func set(highlighter: (any SyntaxHighlighting)?) {
        highlightCoordinator.set(highlighter: highlighter)
    }
}

extension DocumentRenderer {
    struct RenderOutcome {
        let invalidatedHeight: Bool
    }
}

extension DocumentRenderer {
    static func makeTailRevealBatchRange(
        content: NSAttributedString,
        visibleLength: Int,
        policy: TailRevealPolicy
    ) -> NSRange? {
        TailRevealEngine.makeBatchRange(
            content: content,
            visibleLength: visibleLength,
            policy: policy
        )
    }

    static var live: DocumentRenderer {
        DocumentRenderer(
            textView: .init(),
            highlightCoordinator: .live)
    }
}

extension DocumentRenderer {
    struct HighlightableCodeBlock {
        let blockID: BlockIdentity
        let code: String
        let language: String
    }

    struct RenderState {
        var frozenBlockCount = 0
        var smoothedTailFrozenCount: Int?
        var smoothedTailStart: Int?

        mutating func reset() {
            frozenBlockCount = 0
            resetSmoothedTailStart()
        }

        mutating func resetSmoothedTailStart() {
            smoothedTailFrozenCount = nil
            smoothedTailStart = nil
        }

        mutating func updateSmoothedTailStart(
            frozenCount: Int,
            location: Int
        ) {
            smoothedTailFrozenCount = frozenCount
            smoothedTailStart = location
        }

        mutating func updateFrozenBlockCount(to newValue: Int, blockCount: Int) {
            frozenBlockCount = min(newValue, blockCount)
        }
    }
}
