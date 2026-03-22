import QuillCore
import UIKit

@MainActor
final class DocumentRenderer {
    let textView: DocumentTextView
    private var blockIndexer = DocumentBlockIndexer()
    private var highlightCoordinator: HighlightCoordinator
    private var renderState = RenderState()

    convenience init() {
        self.init(textView: .init(), highlightCoordinator: .live)
    }

    init(
        textView: DocumentTextView,
        highlightCoordinator: HighlightCoordinator
    ) {
        self.textView = textView
        self.highlightCoordinator = highlightCoordinator
    }

    func render(blocks: [BlockNode], frozenCount: Int) {
        let fragments = AttributedStringBuilder.buildDocumentFragments(
            from: blocks,
            frozenCount: frozenCount
        )
        let previousFrozenCount = renderState.frozenBlockCount

        if previousFrozenCount == 0, blockIndexer.isEmpty {
            installFullDocument(fragments: fragments, frozenCount: frozenCount)
        } else {
            applyIncrementalUpdate(
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
    }

    func reset() {
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
    static var live: DocumentRenderer {
        DocumentRenderer(textView: .init(), highlightCoordinator: .live)
    }
}

// MARK: - Document Mutations

private extension DocumentRenderer {
    func appendNewlyFrozenContent(
        newDocument: NSAttributedString,
        contentStorage: NSTextContentStorage,
        documentLength: Int
    ) {
        guard let tailRange = blockIndexer.tailRange(
            after: renderState.frozenBlockCount,
            documentLength: documentLength
        ) else {
            replaceTailOnly(
                newDocument: newDocument,
                contentStorage: contentStorage,
                documentLength: documentLength
            )
            return
        }

        let replacementStart = tailRange.location
        let replacementLength = newDocument.length - replacementStart
        guard replacementLength >= 0 else { return }

        let replacementContent = newDocument.attributedSubstring(
            from: NSRange(location: replacementStart, length: replacementLength)
        )

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: tailRange,
                with: replacementContent
            )
        }
    }

    func applyIncrementalUpdate(
        fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int,
        previousFrozenCount: Int
    ) {
        guard let contentStorage = textView.contentStorage,
              let currentString = contentStorage.attributedString
        else { return }

        let newDocument = AttributedStringBuilder.buildDocument(from: fragments)
        let documentLength = currentString.length

        if frozenCount > previousFrozenCount {
            appendNewlyFrozenContent(
                newDocument: newDocument,
                contentStorage: contentStorage,
                documentLength: documentLength
            )
        } else {
            replaceTailOnly(
                newDocument: newDocument,
                contentStorage: contentStorage,
                documentLength: documentLength
            )
        }

        rebuildBlockIndex(from: fragments, frozenCount: frozenCount)
    }

    func installFullDocument(
        fragments: [AttributedStringBuilder.DocumentFragment],
        frozenCount: Int
    ) {
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        guard let contentStorage = textView.contentStorage else { return }

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.setAttributedString(document)
        }

        rebuildBlockIndex(from: fragments, frozenCount: frozenCount)
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

    func replaceTailOnly(
        newDocument: NSAttributedString,
        contentStorage: NSTextContentStorage,
        documentLength: Int
    ) {
        guard let tailRange = blockIndexer.tailRange(
            after: renderState.frozenBlockCount,
            documentLength: documentLength
        ) else {
            let fullRange = NSRange(location: 0, length: documentLength)
            contentStorage.performEditingTransaction {
                contentStorage.textStorage?.replaceCharacters(
                    in: fullRange,
                    with: newDocument
                )
            }
            return
        }

        let newTailContent = newDocument.attributedSubstring(
            from: NSRange(location: tailRange.location, length: newDocument.length - tailRange.location)
        )

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: tailRange,
                with: newTailContent
            )
        }
    }

    func scheduleHighlightsForNewlyFrozenCodeBlocks(
        blocks: [BlockNode],
        fragments: [AttributedStringBuilder.DocumentFragment],
        previousFrozenCount: Int,
        newFrozenCount: Int
    ) {
        guard newFrozenCount > previousFrozenCount else { return }

        for index in previousFrozenCount..<min(newFrozenCount, blocks.count) {
            guard case let .codeBlock(language, code) = blocks[index].block,
                  let language, !language.isEmpty
            else { continue }

            let blockID = fragments[index].blockID
            highlightCoordinator.scheduleHighlight(
                blockID: blockID,
                code: code.hasSuffix("\n") ? String(code.dropLast()) : code,
                language: language
            )
        }
    }
}

private extension DocumentRenderer {
    struct RenderState {
        var frozenBlockCount = 0

        mutating func reset() {
            frozenBlockCount = 0
        }

        mutating func updateFrozenBlockCount(to newValue: Int, blockCount: Int) {
            frozenBlockCount = min(newValue, blockCount)
        }
    }
}
