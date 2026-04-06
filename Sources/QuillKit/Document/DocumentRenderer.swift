import QuillCore
import UIKit

@MainActor
final class DocumentRenderer {
    let textView: DocumentTextView
    var onTailRevealProgress: (() -> Void)? {
        didSet { tailRevealEngine.onProgress = onTailRevealProgress }
    }
    var onImageAspectRatioChanged: (() -> Void)?

    var blockIndexer = DocumentBlockIndexer()
    var highlightCoordinator: HighlightCoordinator
    var imageLoadingCoordinator: ImageLoadingCoordinator
    var renderState = RenderState()
    let tailAnimator = TailAnimator()
    var tailRevealPolicy: TailRevealPolicy?
    lazy var tailRevealEngine = TailRevealEngine { [weak self] batch in
        self?.appendTailRevealBatch(batch) ?? false
    }

    init(
        textView: DocumentTextView,
        highlightCoordinator: HighlightCoordinator,
        imageLoadingCoordinator: ImageLoadingCoordinator
    ) {
        self.textView = textView
        self.highlightCoordinator = highlightCoordinator
        self.imageLoadingCoordinator = imageLoadingCoordinator
        tailRevealEngine.advancePresentation = { [weak self] timestamp in
            self?.advanceTailFade(timestamp: timestamp) ?? false
        }
        tailRevealEngine.hasPresentationWork = { [weak self] in
            self?.tailAnimator.hasActiveSegments ?? false
        }
        self.imageLoadingCoordinator.onAspectRatioChanged = { [weak self] in
            self?.onImageAspectRatioChanged?()
        }
    }

    func applyTailRevealPolicy(_ policy: TailRevealPolicy) {
        tailRevealPolicy = policy
    }

    func cancelStreaming() {
        tailRevealEngine.cancel()
        tailAnimator.cancel()
        highlightCoordinator.cancelAll()
        imageLoadingCoordinator.cancelAll()
        renderState.resetSmoothedTailStart()
    }

    @discardableResult
    func render(blocks: [BlockNode], frozenCount: Int) -> RenderOutcome {
        let fragments = AttributedStringBuilder.buildRenderFragments(
            from: blocks,
            frozenCount: frozenCount,
            highlightStore: highlightCoordinator,
            imageLoadStore: imageLoadingCoordinator,
            imageAppearance: imageLoadingCoordinator.imageAppearance
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
        scheduleImageLoadsForNewlyFrozenBlocks(
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
        imageLoadingCoordinator.reset()
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

    func set(imageLoader: (any ImageLoading)?) {
        imageLoadingCoordinator.set(loader: imageLoader)
    }

    func set(imageOptions: ImageOptions) {
        imageLoadingCoordinator.set(options: imageOptions)
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
            highlightCoordinator: .live,
            imageLoadingCoordinator: .live)
    }
}

extension DocumentRenderer {
    struct HighlightableCodeBlock {
        let blockID: BlockIdentity
        let code: String
        let language: String
    }

    struct LoadableImage {
        let blockID: BlockIdentity
        let source: String?
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
