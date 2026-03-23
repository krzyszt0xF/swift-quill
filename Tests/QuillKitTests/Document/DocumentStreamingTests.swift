@testable import QuillKit
import QuillCore
import QuillCoreTestSupport
import Foundation
import Testing
import UIKit

@MainActor
@Suite("DocumentStreaming")
struct DocumentStreamingTests {
    @Test("Frozen prefix text is not mutated across updates")
    func frozenPrefixStability() {
        let renderer = DocumentRenderer.live

        renderer.render(
            blocks: makeNodes([
                .heading(level: 1, content: [.text("Title")]),
                .paragraph(content: [.text("Body")]),
                .paragraph(content: [.text("Streaming...")]),
            ]),
            frozenCount: 2
        )

        let prefixBefore = extractFrozenText(from: renderer)

        renderer.render(
            blocks: makeNodes([
                .heading(level: 1, content: [.text("Title")]),
                .paragraph(content: [.text("Body")]),
                .paragraph(content: [.text("Streaming more content now")]),
            ]),
            frozenCount: 2
        )

        let prefixAfter = extractFrozenText(from: renderer)

        #expect(prefixBefore == prefixAfter)
        #expect(prefixBefore.contains("Title"))
        #expect(prefixBefore.contains("Body"))
    }

    @Test("Change region is bounded to tail range")
    func boundedChangeRegion() {
        let renderer = DocumentRenderer.live

        renderer.render(
            blocks: makeNodes([
                .paragraph(content: [.text("Frozen A")]),
                .paragraph(content: [.text("Frozen B")]),
                .paragraph(content: [.text("Tail v1")]),
            ]),
            frozenCount: 2
        )

        let frozenPrefix = extractFrozenText(from: renderer)

        renderer.render(
            blocks: makeNodes([
                .paragraph(content: [.text("Frozen A")]),
                .paragraph(content: [.text("Frozen B")]),
                .paragraph(content: [.text("Tail v2 with more text")]),
            ]),
            frozenCount: 2
        )

        let fullAfter = renderer.textView.contentStorage?.attributedString?.string ?? ""
        let frozenPrefixAfter = extractFrozenText(from: renderer)

        #expect(frozenPrefix == frozenPrefixAfter)
        #expect(fullAfter.contains("Tail v2 with more text"))
        #expect(!fullAfter.contains("Tail v1"))
    }

    @Test("Attachment appears after fence close")
    func attachmentAfterFenceClose() {
        let renderer = DocumentRenderer.live

        let blocks: [Block] = [
            .paragraph(content: [.text("Before code")]),
            .codeBlock(language: "swift", code: "print(\"hello\")\n"),
        ]

        renderer.render(blocks: makeNodes(blocks), frozenCount: 1)

        let textBeforeClose = renderer.textView.contentStorage?.attributedString
        #expect(!containsCodeBlockAttachment(in: textBeforeClose))

        renderer.render(blocks: makeNodes(blocks), frozenCount: 2)

        let textAfterClose = renderer.textView.contentStorage?.attributedString
        #expect(containsCodeBlockAttachment(in: textAfterClose))
    }
}

private extension DocumentStreamingTests {
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

    func extractFrozenText(from renderer: DocumentRenderer) -> String {
        guard let text = renderer.textView.contentStorage?.attributedString,
              text.length > 0
        else { return "" }

        return text.string
            .components(separatedBy: "\n")
            .prefix(2)
            .joined(separator: "\n")
    }
}
