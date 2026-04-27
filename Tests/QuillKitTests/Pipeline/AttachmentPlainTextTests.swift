@testable import QuillKit
import QuillCore
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Attachment plain text representation", GloballySerialized())
struct AttachmentPlainTextTests {
    @Test("Code block attachment carries raw source code as plain text")
    func codeBlockPlainText() {
        let code = "let x = 1\nlet y = 2"
        let attributed = EmbeddedBlockRenderer.makeCodeBlockAttachmentAttributedString(
            blockID: BlockIdentity(rawValue: 1),
            code: code,
            highlightStore: nil,
            language: "swift",
            nestingContext: .root,
            theme: .default
        )

        let plainText = attributed.attribute(
            .attachmentPlainText,
            at: 0,
            effectiveRange: nil
        ) as? String

        #expect(plainText == code)
    }

    @Test("Image attachment carries alt text as plain text")
    func imageAltPlainText() {
        let alt = "A screenshot of the dashboard"
        let attributed = EmbeddedBlockRenderer.makeImageAttachmentAttributedString(
            blockID: BlockIdentity(rawValue: 1),
            source: "https://example.com/image.png",
            alt: alt,
            imageLoadStore: nil,
            nestingContext: .root,
            theme: .default
        )

        let plainText = attributed.attribute(
            .attachmentPlainText,
            at: 0,
            effectiveRange: nil
        ) as? String

        #expect(plainText == alt)
    }

    @Test("Image attachment with empty alt carries empty string")
    func imageEmptyAltPlainText() {
        let attributed = EmbeddedBlockRenderer.makeImageAttachmentAttributedString(
            blockID: BlockIdentity(rawValue: 1),
            source: "https://example.com/image.png",
            alt: "",
            imageLoadStore: nil,
            nestingContext: .root,
            theme: .default
        )

        let plainText = attributed.attribute(
            .attachmentPlainText,
            at: 0,
            effectiveRange: nil
        ) as? String

        #expect(plainText?.isEmpty == true)
    }

    @Test("Table attachment carries TSV as plain text")
    func tableAttachmentPlainText() {
        let header = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Name")]),
            Block.TableCell(content: [.text("Value")]),
        ])
        let row = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Quill")]),
            Block.TableCell(content: [.text("1.0")]),
        ])
        let attributed = EmbeddedBlockRenderer.makeTableAttachmentAttributedString(
            blockID: BlockIdentity(rawValue: 1),
            columnAlignments: [nil, nil],
            header: header,
            nestingContext: .root,
            rows: [row],
            theme: .default
        )

        let plainText = attributed.attribute(
            .attachmentPlainText,
            at: 0,
            effectiveRange: nil
        ) as? String

        #expect(plainText == "Name\tValue\nQuill\t1.0")
    }

    @Test("Thematic break has no plain text attribute")
    func thematicBreakNoPlainText() {
        let attributed = EmbeddedBlockRenderer.makeThematicBreakAttributedString(
            theme: .default
        )

        let plainText = attributed.attribute(
            .attachmentPlainText,
            at: 0,
            effectiveRange: nil
        ) as? String

        #expect(plainText == nil)
    }
}
