import QuillCore
import UIKit

extension DocumentRenderer {
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
        fragments: [RenderFragment],
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
