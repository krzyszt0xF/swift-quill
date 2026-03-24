import QuillCore
import UIKit

@MainActor
final class DocumentRenderer {
    let textView: DocumentTextView
    var onTailRevealProgress: (() -> Void)? {
        didSet { tailRevealEngine.onProgress = onTailRevealProgress }
    }

    private var blockIndexer = DocumentBlockIndexer()
    private var highlightCoordinator: HighlightCoordinator
    private var renderState = RenderState()
    private let tailAnimator = TailAnimator()
    private var tailRevealPolicy: TailRevealPolicy?
    private lazy var tailRevealEngine = TailRevealEngine { [weak self] batch in
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
        renderState.resetSmoothedTailStart()
    }

    @discardableResult
    func render(blocks: [BlockNode], frozenCount: Int) -> RenderOutcome {
        let fragments = AttributedStringBuilder.buildDocumentFragments(
            from: blocks,
            frozenCount: frozenCount
        )
        let previousFrozenCount = renderState.frozenBlockCount
        let renderOutcome: RenderOutcome

        if shouldUseSmoothedTail(frozenCount: frozenCount, blockCount: blocks.count) {
            renderOutcome = renderWithSmoothedTail(
                fragments: fragments,
                frozenCount: frozenCount,
                previousFrozenCount: previousFrozenCount
            )
        } else {
            renderOutcome = renderImmediately(
                fragments: fragments,
                frozenCount: frozenCount,
                previousFrozenCount: previousFrozenCount
            )
        }

        scheduleHighlightsForNewlyFrozenCodeBlocks(
            blocks: blocks,
            fragments: fragments,
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
    }

    func set(highlighter: (any SyntaxHighlighter)?) {
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

// MARK: - Document Mutations

private extension DocumentRenderer {
    func appendNewlyFrozenContent(
        newDocument: NSAttributedString,
        contentStorage: NSTextContentStorage,
        documentLength: Int
    ) -> Bool {
        guard let tailRange = blockIndexer.tailRange(
            after: renderState.frozenBlockCount,
            documentLength: documentLength
        ) else {
            return replaceTailOnly(
                newDocument: newDocument,
                contentStorage: contentStorage,
                documentLength: documentLength
            )
        }

        let replacementStart = tailRange.location
        let replacementLength = newDocument.length - replacementStart
        guard replacementLength >= 0 else { return false }

        let replacementContent = newDocument.attributedSubstring(
            from: NSRange(location: replacementStart, length: replacementLength)
        )

        return replaceCharactersIfNeeded(
            in: tailRange,
            with: replacementContent,
            contentStorage: contentStorage
        )
    }

    func appendTailRevealBatch(_ batch: NSAttributedString) -> Bool {
        guard let contentStorage = textView.contentStorage,
              let tailRevealPolicy
        else { return false }

        let insertLocation = contentStorage.attributedString?.length ?? 0
        let presentedBatch = tailAnimator.prepareBatchForAppend(
            batch,
            policy: tailRevealPolicy
        )
        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: insertLocation, length: 0),
                with: presentedBatch
            )
        }

        return true
    }

    func installFullDocument(
        fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int
    ) -> Bool {
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        guard let contentStorage = textView.contentStorage else { return false }

        let fullRange = NSRange(location: 0, length: contentStorage.attributedString?.length ?? 0)
        let didMutate = replaceCharactersIfNeeded(
            in: fullRange,
            with: document,
            contentStorage: contentStorage
        )

        rebuildBlockIndex(from: fragments, frozenCount: frozenCount)
        return didMutate
    }

    func replaceTailOnly(
        newDocument: NSAttributedString,
        contentStorage: NSTextContentStorage,
        documentLength: Int
    ) -> Bool {
        guard let tailRange = blockIndexer.tailRange(
            after: renderState.frozenBlockCount,
            documentLength: documentLength
        ) else {
            let fullRange = NSRange(location: 0, length: documentLength)
            return replaceCharactersIfNeeded(
                in: fullRange,
                with: newDocument,
                contentStorage: contentStorage
            )
        }

        let newTailContent = newDocument.attributedSubstring(
            from: NSRange(location: tailRange.location, length: newDocument.length - tailRange.location)
        )

        return replaceCharactersIfNeeded(
            in: tailRange,
            with: newTailContent,
            contentStorage: contentStorage
        )
    }

    func makeDesiredTailContent(
        in document: NSAttributedString,
        tailStart: Int
    ) -> NSAttributedString {
        guard document.length > tailStart else { return NSAttributedString() }

        return document.attributedSubstring(
            from: NSRange(location: tailStart, length: document.length - tailStart)
        )
    }

    func rebuildBlockIndex(
        from fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int
    ) {
        blockIndexer.rebuild(
            from: fragments,
            preservingPrefixCount: renderState.frozenBlockCount
        )
        renderState.updateFrozenBlockCount(
            to: frozenCount,
            blockCount: blockIndexer.blockSpans.count
        )
    }

    func makeSmoothedTailStart(
        documentLength: Int,
        frozenCount: Int
    ) -> Int {
        if renderState.smoothedTailFrozenCount == frozenCount,
           let smoothedTailStart = renderState.smoothedTailStart {
            return smoothedTailStart
        }

        let smoothedTailStart = blockIndexer.tailRange(
            after: frozenCount,
            documentLength: documentLength
        )?.location ?? documentLength
        renderState.updateSmoothedTailStart(
            frozenCount: frozenCount,
            location: smoothedTailStart
        )
        return smoothedTailStart
    }

    func renderImmediately(
        fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int,
        previousFrozenCount: Int
    ) -> RenderOutcome {
        tailRevealEngine.cancel()
        tailAnimator.cancel()
        renderState.resetSmoothedTailStart()

        guard let contentStorage = textView.contentStorage,
              let currentString = contentStorage.attributedString
        else {
            let didMutate = installFullDocument(fragments: fragments, frozenCount: frozenCount)
            return RenderOutcome(invalidatedHeight: didMutate)
        }

        let newDocument = AttributedStringBuilder.buildDocument(from: fragments)
        let documentLength = currentString.length
        let didMutateVisibleContent: Bool

        if previousFrozenCount == 0, blockIndexer.isEmpty {
            didMutateVisibleContent = installFullDocument(
                fragments: fragments,
                frozenCount: frozenCount
            )
        } else if frozenCount > previousFrozenCount {
            didMutateVisibleContent = appendNewlyFrozenContent(
                newDocument: newDocument,
                contentStorage: contentStorage,
                documentLength: documentLength
            )
            rebuildBlockIndex(from: fragments, frozenCount: frozenCount)
        } else {
            didMutateVisibleContent = replaceTailOnly(
                newDocument: newDocument,
                contentStorage: contentStorage,
                documentLength: documentLength
            )
            rebuildBlockIndex(from: fragments, frozenCount: frozenCount)
        }

        return RenderOutcome(invalidatedHeight: didMutateVisibleContent)
    }

    func renderWithSmoothedTail(
        fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int,
        previousFrozenCount: Int
    ) -> RenderOutcome {
        guard let tailRevealPolicy,
              let contentStorage = textView.contentStorage
        else {
            return renderImmediately(
                fragments: fragments,
                frozenCount: frozenCount,
                previousFrozenCount: previousFrozenCount
            )
        }

        let desiredDocument = AttributedStringBuilder.buildDocument(from: fragments)
        let currentDocumentLength = contentStorage.attributedString?.length ?? 0
        let currentTailStart = makeSmoothedTailStart(
            documentLength: currentDocumentLength,
            frozenCount: previousFrozenCount
        )
        let desiredTail = makeDesiredTailContent(
            in: desiredDocument,
            tailStart: currentTailStart
        )
        let displayedTail = tailRevealEngine.rebase(
            to: desiredTail,
            policy: tailRevealPolicy
        )
        let presentedTail = tailAnimator.rebaseVisibleContent(
            to: displayedTail,
            tailStart: currentTailStart
        )

        let didMutateVisibleContent = replaceCharactersIfNeeded(
            in: NSRange(location: currentTailStart, length: currentDocumentLength - currentTailStart),
            with: presentedTail,
            contentStorage: contentStorage
        )

        rebuildBlockIndex(from: fragments, frozenCount: frozenCount)
        if frozenCount < fragments.count {
            renderState.updateSmoothedTailStart(
                frozenCount: frozenCount,
                location: currentTailStart
            )
        } else {
            renderState.resetSmoothedTailStart()
        }
        return RenderOutcome(invalidatedHeight: didMutateVisibleContent)
    }

    func scheduleHighlightsForNewlyFrozenCodeBlocks(
        blocks: [BlockNode],
        fragments: [AttributedStringBuilder.DocumentFragment],
        previousFrozenCount: Int,
        newFrozenCount: Int
    ) {
        guard newFrozenCount > previousFrozenCount else { return }

        for index in previousFrozenCount..<min(newFrozenCount, min(blocks.count, fragments.count)) {
            guard
                case let .codeBlock(language, code) = blocks[index].block,
                let language,
                !language.isEmpty
            else { continue }

            let blockID = fragments[index].blockID
            highlightCoordinator.scheduleHighlight(
                blockID: blockID,
                code: code.hasSuffix("\n") ? String(code.dropLast()) : code,
                language: language
            )
        }
    }

    func shouldUseSmoothedTail(frozenCount: Int, blockCount: Int) -> Bool {
        guard tailRevealPolicy != nil else { return false }

        return frozenCount < blockCount
    }

    func replaceCharactersIfNeeded(
        in range: NSRange,
        with replacement: NSAttributedString,
        contentStorage: NSTextContentStorage
    ) -> Bool {
        let currentLength = contentStorage.attributedString?.length ?? 0
        guard range.location >= 0, range.location + range.length <= currentLength else {
            return false
        }

        let existingContent = contentStorage.attributedString?.attributedSubstring(from: range) ?? NSAttributedString()
        guard existingContent.isEqual(to: replacement) == false else { return false }

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: range,
                with: replacement
            )
        }

        return true
    }

    func advanceTailFade(timestamp: CFTimeInterval) -> Bool {
        guard let contentStorage = textView.contentStorage else {
            tailAnimator.cancel()
            return false
        }

        return tailAnimator.advancePresentation(
            in: contentStorage,
            now: timestamp
        )
    }
}

private extension DocumentRenderer {
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
