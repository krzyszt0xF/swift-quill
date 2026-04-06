import QuillCore
import UIKit

enum EmbeddedBlockRenderer {
    static func makeCodeBlockAttachmentAttributedString(
        blockID: BlockIdentity,
        code: String,
        highlightStore: (any CodeBlockHighlightStore)?,
        language: String?,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock
    ) -> NSAttributedString {
        let attachment = CodeBlockAttachment(
            blockID: blockID,
            language: language,
            code: code
        )
        attachment.highlightStore = highlightStore
        return makePresentationRoleAttributedString(
            attachment: attachment,
            nestingContext: nestingContext,
            presentationRole: presentationRole
        )
    }

    static func makeImageAttachmentAttributedString(
        blockID: BlockIdentity,
        source: String?,
        alt: String,
        imageLoadStore: (any ImageLoadStore)?,
        appearance: ImageAppearance,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock
    ) -> NSAttributedString {
        let attachment = ImageAttachment(
            blockID: blockID,
            source: source,
            alt: alt.isEmpty ? "image" : alt,
            appearance: appearance
        )
        attachment.imageLoadStore = imageLoadStore
        return makePresentationRoleAttributedString(
            attachment: attachment,
            nestingContext: nestingContext,
            presentationRole: presentationRole
        )
    }

    static func makeOpenCodeFenceAttributedString(
        code: String,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock
    ) -> NSAttributedString {
        makePresentationRoleAttributedString(
            string: code,
            attributes: [
                .font: BlockStyleFactory.monospaceFont(),
                .foregroundColor: UIColor.label,
            ],
            nestingContext: nestingContext,
            presentationRole: presentationRole
        )
    }

    static func makeTableAttachmentAttributedString(
        blockID: BlockIdentity,
        columnAlignments: [Block.ColumnAlignment?],
        header: Block.TableRow,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock,
        rows: [Block.TableRow]
    ) -> NSAttributedString {
        let attachment = TableAttachment(
            blockID: blockID,
            columnAlignments: columnAlignments,
            header: header,
            rows: rows
        )
        return makePresentationRoleAttributedString(
            attachment: attachment,
            nestingContext: nestingContext,
            presentationRole: presentationRole
        )
    }

    static func makeTableFallbackAttributedString(
        header: Block.TableRow,
        rows: [Block.TableRow],
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock
    ) -> NSAttributedString {
        var lines: [String] = []
        let headerCells = header.cells.map { InlineContentRenderer.plainText(from: $0.content) }

        lines.append("| " + headerCells.joined(separator: " | ") + " |")
        let separators = headerCells.map { String(repeating: "-", count: max($0.count, 3)) }
        lines.append("| " + separators.joined(separator: " | ") + " |")

        for row in rows {
            let cells = row.cells.map { InlineContentRenderer.plainText(from: $0.content) }
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }

        return makePresentationRoleAttributedString(
            string: lines.joined(separator: "\n"),
            attributes: [
                .font: BlockStyleFactory.monospaceFont(),
                .foregroundColor: UIColor.label,
            ],
            nestingContext: nestingContext,
            presentationRole: presentationRole
        )
    }

    static func makeThematicBreakAttributedString() -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = thematicBreakImage
        attachment.bounds = CGRect(x: 0, y: 0, width: 10000, height: 1)

        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttribute(
            .paragraphStyle,
            value: BlockStyleFactory.makeThematicBreakParagraphStyle(),
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }
}

private extension EmbeddedBlockRenderer {
    static func applyPresentationRoleAttributes(
        to attributedString: NSMutableAttributedString,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole
    ) {
        let style = BlockStyleFactory.makePresentationRoleParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: 8,
            presentationRole: presentationRole
        )
        attributedString.addAttribute(
            .paragraphStyle,
            value: style,
            range: NSRange(location: 0, length: attributedString.length)
        )
    }

    static func makePresentationRoleAttributedString(
        attachment: NSTextAttachment,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(attachment: attachment)
        applyPresentationRoleAttributes(
            to: result,
            nestingContext: nestingContext,
            presentationRole: presentationRole
        )
        return result
    }

    static func makePresentationRoleAttributedString(
        string: String,
        attributes: [NSAttributedString.Key: Any],
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: string, attributes: attributes)
        applyPresentationRoleAttributes(
            to: result,
            nestingContext: nestingContext,
            presentationRole: presentationRole
        )
        return result
    }

    static let thematicBreakImage: UIImage = {
        let size = CGSize(width: 10000, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.separator.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }()
}
