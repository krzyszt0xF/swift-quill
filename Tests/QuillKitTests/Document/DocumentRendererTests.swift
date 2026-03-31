@testable import QuillKit
import QuillCore
import QuillCoreTestSupport
import Foundation
import Testing
import UIKit

@MainActor
@Suite("DocumentRenderer")
struct DocumentRendererTests {
    @Test("First render of static document installs content")
    func staticDocumentRender() {
        let renderer = DocumentRenderer.live
        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .paragraph(content: [.text("World")]),
        ]

        renderer.render(blocks: makeNodes(blocks), frozenCount: blocks.count)

        let text = renderer.textView.contentStorage?.attributedString
        #expect(text != nil)
        #expect(text?.string.contains("Hello") == true)
        #expect(text?.string.contains("World") == true)
    }

    @Test("Repeated render with growing frozen prefix appends content")
    func growingFrozenPrefix() {
        let renderer = DocumentRenderer.live
        let blocks: [Block] = [
            .paragraph(content: [.text("First")]),
            .paragraph(content: [.text("Second")]),
            .paragraph(content: [.text("Third")]),
        ]

        renderer.render(blocks: makeNodes(Array(blocks.prefix(2))), frozenCount: 1)
        let textAfterFirst = renderer.textView.contentStorage?.attributedString?.string ?? ""
        #expect(textAfterFirst.contains("First"))
        #expect(textAfterFirst.contains("Second"))

        renderer.render(blocks: makeNodes(blocks), frozenCount: 2)
        let textAfterSecond = renderer.textView.contentStorage?.attributedString?.string ?? ""
        #expect(textAfterSecond.contains("First"))
        #expect(textAfterSecond.contains("Second"))
        #expect(textAfterSecond.contains("Third"))
    }

    @Test("Tail-only replacement when frozenCount unchanged")
    func tailOnlyReplacement() {
        let renderer = DocumentRenderer.live

        renderer.render(
            blocks: makeNodes([
                .paragraph(content: [.text("Frozen")]),
                .paragraph(content: [.text("Tail v1")]),
            ]),
            frozenCount: 1
        )

        let prefixBefore = extractPrefix(from: renderer, frozenCount: 1)

        renderer.render(
            blocks: makeNodes([
                .paragraph(content: [.text("Frozen")]),
                .paragraph(content: [.text("Tail v2")]),
            ]),
            frozenCount: 1
        )

        let prefixAfter = extractPrefix(from: renderer, frozenCount: 1)
        let fullText = renderer.textView.contentStorage?.attributedString?.string ?? ""

        #expect(prefixBefore == prefixAfter)
        #expect(fullText.contains("Tail v2"))
        #expect(!fullText.contains("Tail v1"))
    }

    @Test("Closed code fence produces attachment")
    func closedCodeFenceAttachment() {
        let renderer = DocumentRenderer.live
        let blocks: [Block] = [
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]

        renderer.render(blocks: makeNodes(blocks), frozenCount: 1)

        let text = renderer.textView.contentStorage?.attributedString
        #expect(text != nil)
        #expect(containsAttachment(CodeBlockAttachment.self, in: text))
    }

    @Test("List with nested code block renders full-width attachment for frozen list")
    func frozenListNestedCodeBlockAttachment() {
        let renderer = DocumentRenderer.live
        let blocks: [Block] = [
            .orderedList(startIndex: 1, items: [
                makeItem(
                    .paragraph(content: [.text("Code")]),
                    .codeBlock(language: "swift", code: "print(\"Hello\")\n")
                ),
            ]),
        ]

        renderer.render(blocks: makeNodes(blocks), frozenCount: 1)

        let text = renderer.textView.contentStorage?.attributedString
        let attachmentIndex = firstAttachmentIndex(in: text)
        let paragraphStyle = attachmentIndex.flatMap {
            text?.attribute(.paragraphStyle, at: $0, effectiveRange: nil) as? NSParagraphStyle
        }

        #expect(text?.string.contains("Code") == true)
        #expect(attachmentIndex != nil)
        #expect(containsAttachment(CodeBlockAttachment.self, in: text))
        #expect(paragraphStyle?.headIndent == 0)
    }

    @Test("Open code fence remains plain text before close")
    func openCodeFencePlainText() {
        let renderer = DocumentRenderer.live
        let blocks: [Block] = [
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]

        renderer.render(blocks: makeNodes(blocks), frozenCount: 0)

        let text = renderer.textView.contentStorage?.attributedString
        #expect(text != nil)
        #expect(!containsAttachment(CodeBlockAttachment.self, in: text))
        #expect(text?.string.contains("let x = 1") == true)
    }

    @Test("Stable prefix ranges after tail mutations")
    func stablePrefixRanges() {
        let renderer = DocumentRenderer.live

        renderer.render(
            blocks: makeNodes([
                .paragraph(content: [.text("Stable")]),
                .paragraph(content: [.text("Tail A")]),
            ]),
            frozenCount: 1
        )

        let prefixText1 = extractPrefix(from: renderer, frozenCount: 1)

        renderer.render(
            blocks: makeNodes([
                .paragraph(content: [.text("Stable")]),
                .paragraph(content: [.text("Longer tail content here")]),
            ]),
            frozenCount: 1
        )

        let prefixText2 = extractPrefix(from: renderer, frozenCount: 1)

        renderer.render(
            blocks: makeNodes([
                .paragraph(content: [.text("Stable")]),
                .paragraph(content: [.text("Short")]),
            ]),
            frozenCount: 1
        )

        let prefixText3 = extractPrefix(from: renderer, frozenCount: 1)

        #expect(prefixText1 == prefixText2)
        #expect(prefixText2 == prefixText3)
        #expect(prefixText1.contains("Stable"))
    }

    @Test("Buffered modules still reveal the mutable tail progressively")
    func bufferedModulesUseSmoothedTailReveal() {
        let renderer = DocumentRenderer.live
        renderer.applyTailRevealPolicy(.balanced)

        renderer.render(
            blocks: makeNodes([
                .paragraph(content: [.text("Frozen")]),
                .paragraph(content: [.text("Tail content appears gradually")]),
            ]),
            frozenCount: 1
        )

        let text = renderer.textView.contentStorage?.attributedString?.string ?? ""

        #expect(text.contains("Frozen"))
        #expect(text != "Frozen\nTail content appears gradually")
    }

    @Test("Tail reveal prefers burst-sized batches for longer words")
    func tailRevealBatchRangePrefersBurstOverFullWord() {
        let range = DocumentRenderer.makeTailRevealBatchRange(
            content: NSAttributedString(string: "animation smoothness"),
            visibleLength: 0,
            policy: .balanced
        )

        #expect(range?.location == 0)
        #expect(range?.length == 4)
    }

    @Test("Tail reveal softly snaps to a nearby word boundary")
    func tailRevealBatchRangeSnapsToNearbyWordBoundary() {
        let range = DocumentRenderer.makeTailRevealBatchRange(
            content: NSAttributedString(string: "flow more"),
            visibleLength: 0,
            policy: .balanced
        )

        #expect(range?.location == 0)
        #expect(range?.length == 5)
    }

    @Test("Smoothed tail shows full content once the document becomes fully frozen")
    func smoothedTailFinishesImmediatelyWhenTailDisappears() {
        let renderer = DocumentRenderer.live
        renderer.applyTailRevealPolicy(.balanced)

        let blocks = makeNodes([
            .paragraph(content: [.text("Frozen")]),
            .paragraph(content: [.text("Tail content appears gradually")]),
        ])

        renderer.render(blocks: blocks, frozenCount: 1)
        renderer.render(blocks: blocks, frozenCount: 2)

        let text = renderer.textView.contentStorage?.attributedString?.string ?? ""

        #expect(text.contains("Frozen"))
        #expect(text.contains("Tail content appears gradually"))
    }

    @Test("Repeated identical static render is a no-op for height invalidation")
    func repeatedIdenticalStaticRenderDoesNotInvalidateHeight() {
        let renderer = DocumentRenderer.live
        let blocks = makeNodes([
            .paragraph(content: [.text("Hello")]),
            .paragraph(content: [.text("World")]),
        ])

        let firstOutcome = renderer.render(blocks: blocks, frozenCount: 2)
        let secondOutcome = renderer.render(blocks: blocks, frozenCount: 2)

        #expect(firstOutcome.invalidatedHeight == true)
        #expect(secondOutcome.invalidatedHeight == false)
    }

    @Test("Repeated identical smoothed-tail snapshot is a no-op for height invalidation")
    func repeatedIdenticalSmoothedTailSnapshotDoesNotInvalidateHeight() {
        let renderer = DocumentRenderer.live
        renderer.applyTailRevealPolicy(.balanced)

        let blocks = makeNodes([
            .paragraph(content: [.text("Frozen")]),
            .paragraph(content: [.text("Tail content appears gradually")]),
        ])

        _ = renderer.render(blocks: blocks, frozenCount: 1)
        let secondOutcome = renderer.render(blocks: blocks, frozenCount: 1)

        #expect(secondOutcome.invalidatedHeight == false)
    }

    @Test("Reset clears content and state")
    func resetClearsEverything() {
        let renderer = DocumentRenderer.live
        renderer.render(
            blocks: makeNodes([.paragraph(content: [.text("Content")])]),
            frozenCount: 1
        )

        #expect(renderer.textView.contentStorage?.attributedString?.length ?? 0 > 0)

        renderer.reset()

        let length = renderer.textView.contentStorage?.attributedString?.length ?? 0
        #expect(length == 0)
    }
}

private extension DocumentRendererTests {
    func extractPrefix(from renderer: DocumentRenderer, frozenCount: Int) -> String {
        guard let text = renderer.textView.contentStorage?.attributedString,
              text.length > 0
        else { return "" }

        let fragments = text.string.components(separatedBy: "\n")
        return fragments.prefix(frozenCount).joined(separator: "\n")
    }
}
