@testable import QuillKit
import QuillCore
import QuillCoreTestSupport
import Foundation
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("DocumentStreaming", .tags(.rendering, .streaming))
struct DocumentStreamingTests {
    @Test("Frozen prefix text is not mutated across updates")
    func frozenPrefixStability() {
        let renderer = DocumentRenderer.live

        renderer.render(
            blocks: [
                .heading(level: 1, content: [.text("Title")]),
                .paragraph(content: [.text("Body")]),
                .paragraph(content: [.text("Streaming...")]),
            ].makeNodes(),
            frozenCount: 2
        )

        let prefixBefore = extractFrozenText(from: renderer)

        renderer.render(
            blocks: [
                .heading(level: 1, content: [.text("Title")]),
                .paragraph(content: [.text("Body")]),
                .paragraph(content: [.text("Streaming more content now")]),
            ].makeNodes(),
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
            blocks: [
                .paragraph(content: [.text("Frozen A")]),
                .paragraph(content: [.text("Frozen B")]),
                .paragraph(content: [.text("Tail v1")]),
            ].makeNodes(),
            frozenCount: 2
        )

        let frozenPrefix = extractFrozenText(from: renderer)

        renderer.render(
            blocks: [
                .paragraph(content: [.text("Frozen A")]),
                .paragraph(content: [.text("Frozen B")]),
                .paragraph(content: [.text("Tail v2 with more text")]),
            ].makeNodes(),
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

        renderer.render(blocks: blocks.makeNodes(), frozenCount: 1)

        let textBeforeClose = renderer.textView.contentStorage?.attributedString
        #expect(textBeforeClose?.containsAttachment(CodeBlockAttachment.self) != true)

        renderer.render(blocks: blocks.makeNodes(), frozenCount: 2)

        let textAfterClose = renderer.textView.contentStorage?.attributedString
        #expect(textAfterClose?.containsAttachment(CodeBlockAttachment.self) == true)
    }

    @Test("Table block becomes attachment surface on freeze")
    func tableFreeze() {
        let renderer = DocumentRenderer.live
        renderer.textView.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        let blocks: [Block] = [
            .paragraph(content: [.text("Before table")]),
            .table(
                columnAlignments: [.left, .center],
                header: Block.TableRow(cells: [
                    Block.TableCell(content: [.text("Feature")]),
                    Block.TableCell(content: [.text("Status")]),
                ]),
                rows: [
                    Block.TableRow(cells: [
                        Block.TableCell(content: [.strong([.text("Tables")])]),
                        Block.TableCell(content: [.emphasis([.text("ready")])]),
                    ]),
                ]
            ),
        ]

        renderer.render(blocks: blocks.makeNodes(), frozenCount: 1)

        let textBeforeFreeze = renderer.textView.contentStorage?.attributedString
        #expect(textBeforeFreeze?.string.contains("|") == true)
        #expect(textBeforeFreeze?.containsAttachment(TableAttachment.self) != true)

        renderer.render(blocks: blocks.makeNodes(), frozenCount: 2)

        let textAfterFreeze = renderer.textView.contentStorage?.attributedString
        #expect(textAfterFreeze?.containsAttachment(TableAttachment.self) == true)
    }
}

private extension DocumentStreamingTests {
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
