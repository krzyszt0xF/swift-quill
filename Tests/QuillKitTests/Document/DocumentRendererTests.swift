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
        let renderer = DocumentRenderer()
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
        let renderer = DocumentRenderer()
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
        let renderer = DocumentRenderer()

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
        let renderer = DocumentRenderer()
        let blocks: [Block] = [
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]

        renderer.render(blocks: makeNodes(blocks), frozenCount: 1)

        let text = renderer.textView.contentStorage?.attributedString
        #expect(text != nil)
        #expect(containsCodeBlockAttachment(in: text))
    }

    @Test("Open code fence remains plain text before close")
    func openCodeFencePlainText() {
        let renderer = DocumentRenderer()
        let blocks: [Block] = [
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]

        renderer.render(blocks: makeNodes(blocks), frozenCount: 0)

        let text = renderer.textView.contentStorage?.attributedString
        #expect(text != nil)
        #expect(!containsCodeBlockAttachment(in: text))
        #expect(text?.string.contains("let x = 1") == true)
    }

    @Test("Stable prefix ranges after tail mutations")
    func stablePrefixRanges() {
        let renderer = DocumentRenderer()

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

    @Test("Reset clears content and state")
    func resetClearsEverything() {
        let renderer = DocumentRenderer()
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
    func containsCodeBlockAttachment(in attributedString: NSAttributedString?) -> Bool {
        guard let attributedString, attributedString.length > 0 else { return false }

        var found = false
        attributedString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: attributedString.length)
        ) { value, _, stop in
            if value is CodeBlockAttachment {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    func extractPrefix(from renderer: DocumentRenderer, frozenCount: Int) -> String {
        guard let text = renderer.textView.contentStorage?.attributedString,
              text.length > 0
        else { return "" }

        let fragments = text.string.components(separatedBy: "\n")
        return fragments.prefix(frozenCount).joined(separator: "\n")
    }
}
