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
    }

    func applyTailRevealPolicy(_ policy: TailRevealPolicy) {
        tailRevealPolicy = policy
    }

    func cancelStreaming() {
        tailRevealEngine.cancel()
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
        guard let contentStorage = textView.contentStorage else { return false }

        let insertLocation = contentStorage.attributedString?.length ?? 0
        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: insertLocation, length: 0),
                with: batch
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

    func makeCachedPrefixLength(
        from fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int
    ) -> Int {
        if renderState.frozenPrefixCount == frozenCount {
            return renderState.frozenPrefixLength
        }

        let prefixLength = makePrefixLength(from: fragments, frozenCount: frozenCount)
        renderState.updateFrozenPrefix(count: frozenCount, length: prefixLength)
        return prefixLength
    }

    func makeDesiredTailContent(
        in document: NSAttributedString,
        prefixLength: Int
    ) -> NSAttributedString {
        guard document.length > prefixLength else { return NSAttributedString() }

        return document.attributedSubstring(
            from: NSRange(location: prefixLength, length: document.length - prefixLength)
        )
    }

    func makePrefixLength(
        from fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int
    ) -> Int {
        guard frozenCount > 0 else { return 0 }

        let prefixLimit = min(frozenCount, fragments.count)
        var length = 0

        for index in 0..<prefixLimit {
            if index > 0 {
                length += 1
            }
            length += fragments[index].attributedString.length
        }

        return length
    }

    func rebuildBlockIndex(
        from fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int
    ) {
        blockIndexer.rebuild(
            from: fragments,
            preservingPrefixCount: renderState.frozenBlockCount
        )
        renderState.updateFrozenPrefix(
            count: frozenCount,
            length: makePrefixLength(from: fragments, frozenCount: frozenCount)
        )
        renderState.updateFrozenBlockCount(
            to: frozenCount,
            blockCount: blockIndexer.blockSpans.count
        )
    }

    func renderImmediately(
        fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int,
        previousFrozenCount: Int
    ) -> RenderOutcome {
        tailRevealEngine.cancel()

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
        let prefixLength = makeCachedPrefixLength(from: fragments, frozenCount: frozenCount)
        let desiredTail = makeDesiredTailContent(in: desiredDocument, prefixLength: prefixLength)
        let currentDocumentLength = contentStorage.attributedString?.length ?? 0
        let currentTailStart = blockIndexer.tailRange(
            after: previousFrozenCount,
            documentLength: currentDocumentLength
        )?.location ?? currentDocumentLength
        let displayedTail = tailRevealEngine.rebase(
            to: desiredTail,
            policy: tailRevealPolicy
        )

        let didMutateVisibleContent = replaceCharactersIfNeeded(
            in: NSRange(location: currentTailStart, length: currentDocumentLength - currentTailStart),
            with: displayedTail,
            contentStorage: contentStorage
        )

        rebuildBlockIndex(from: fragments, frozenCount: frozenCount)
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
}

private extension DocumentRenderer {
    struct RenderState {
        var frozenBlockCount = 0
        var frozenPrefixCount = 0
        var frozenPrefixLength = 0

        mutating func reset() {
            frozenBlockCount = 0
            frozenPrefixCount = 0
            frozenPrefixLength = 0
        }

        mutating func updateFrozenPrefix(count: Int, length: Int) {
            frozenPrefixCount = count
            frozenPrefixLength = length
        }

        mutating func updateFrozenBlockCount(to newValue: Int, blockCount: Int) {
            frozenBlockCount = min(newValue, blockCount)
        }
    }
}
