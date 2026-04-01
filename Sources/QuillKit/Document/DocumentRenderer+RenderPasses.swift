import QuillCore
import UIKit

extension DocumentRenderer {
    func makeRenderOutcome(
        from fragments: [RenderFragment],
        frozenCount: Int,
        previousFrozenCount: Int,
        blockCount: Int
    ) -> RenderOutcome {
        if shouldUseSmoothedTail(frozenCount: frozenCount, blockCount: blockCount) {
            return renderWithSmoothedTail(
                fragments: fragments,
                frozenCount: frozenCount,
                previousFrozenCount: previousFrozenCount
            )
        }

        return renderImmediately(
            fragments: fragments,
            frozenCount: frozenCount,
            previousFrozenCount: previousFrozenCount
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
        from fragments: [RenderFragment],
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
        fragments: [RenderFragment],
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
        fragments: [RenderFragment],
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
        if frozenCount < blockIndexer.blockSpans.count {
            renderState.updateSmoothedTailStart(
                frozenCount: frozenCount,
                location: currentTailStart
            )
        } else {
            renderState.resetSmoothedTailStart()
        }
        return RenderOutcome(invalidatedHeight: didMutateVisibleContent)
    }

    func shouldUseSmoothedTail(frozenCount: Int, blockCount: Int) -> Bool {
        guard tailRevealPolicy != nil else { return false }

        return frozenCount < blockCount
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
