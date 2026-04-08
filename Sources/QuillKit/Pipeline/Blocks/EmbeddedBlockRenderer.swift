import QuillCore
import UIKit

enum EmbeddedBlockRenderer {
    static func makeCodeBlockAttachmentAttributedString(
        blockID: BlockIdentity,
        code: String,
        highlightStore: (any CodeBlockHighlightStore)?,
        language: String?,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock,
        theme: QuillTheme
    ) -> NSAttributedString {
        let attachment = CodeBlockAttachment(
            blockID: blockID,
            language: language,
            code: code,
            theme: theme
        )
        attachment.highlightStore = highlightStore
        return makePresentationRoleAttributedString(
            attachment: attachment,
            nestingContext: nestingContext,
            presentationRole: presentationRole,
            theme: theme
        )
    }

    static func makeImageAttachmentAttributedString(
        blockID: BlockIdentity,
        source: String?,
        alt: String,
        imageLoadStore: (any ImageLoadStore)?,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock,
        theme: QuillTheme
    ) -> NSAttributedString {
        let attachment = ImageAttachment(
            blockID: blockID,
            source: source,
            alt: alt.isEmpty ? "image" : alt,
            theme: theme
        )
        attachment.imageLoadStore = imageLoadStore
        return makePresentationRoleAttributedString(
            attachment: attachment,
            nestingContext: nestingContext,
            presentationRole: presentationRole,
            theme: theme
        )
    }

    static func makeOpenCodeFenceAttributedString(
        code: String,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock,
        theme: QuillTheme
    ) -> NSAttributedString {
        makePresentationRoleAttributedString(
            string: code,
            attributes: [
                .font: BlockStyleFactory.monospaceFont(theme: theme),
                .foregroundColor: theme.codeBlock.textColor,
            ],
            nestingContext: nestingContext,
            presentationRole: presentationRole,
            theme: theme
        )
    }

    static func makeTableAttachmentAttributedString(
        blockID: BlockIdentity,
        columnAlignments: [Block.ColumnAlignment?],
        header: Block.TableRow,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock,
        rows: [Block.TableRow],
        theme: QuillTheme
    ) -> NSAttributedString {
        let attachment = TableAttachment(
            blockID: blockID,
            columnAlignments: columnAlignments,
            header: header,
            rows: rows,
            theme: theme
        )
        return makePresentationRoleAttributedString(
            attachment: attachment,
            nestingContext: nestingContext,
            presentationRole: presentationRole,
            theme: theme
        )
    }

    static func makeTableFallbackAttributedString(
        header: Block.TableRow,
        rows: [Block.TableRow],
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock,
        theme: QuillTheme
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
                .font: theme.table.bodyFont,
                .foregroundColor: theme.body.textColor,
            ],
            nestingContext: nestingContext,
            presentationRole: presentationRole,
            theme: theme
        )
    }

    static func makeThematicBreakAttributedString(theme: QuillTheme) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = makeThematicBreakImage(theme: theme)
        attachment.bounds = CGRect(x: 0, y: 0, width: 10000, height: 1)

        let result = NSMutableAttributedString(attachment: attachment)
        result.addAttribute(
            .paragraphStyle,
            value: BlockStyleFactory.makeThematicBreakParagraphStyle(theme: theme),
            range: NSRange(location: 0, length: result.length)
        )
        return result
    }
}

private extension EmbeddedBlockRenderer {
    static func applyPresentationRoleAttributes(
        to attributedString: NSMutableAttributedString,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole,
        theme: QuillTheme
    ) {
        let style = BlockStyleFactory.makePresentationRoleParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: theme.blockSpacingScaled,
            presentationRole: presentationRole,
            theme: theme
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
        presentationRole: RenderFragment.PresentationRole,
        theme: QuillTheme
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(attachment: attachment)
        applyPresentationRoleAttributes(
            to: result,
            nestingContext: nestingContext,
            presentationRole: presentationRole,
            theme: theme
        )
        return result
    }

    static func makePresentationRoleAttributedString(
        string: String,
        attributes: [NSAttributedString.Key: Any],
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole,
        theme: QuillTheme
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: string, attributes: attributes)
        applyPresentationRoleAttributes(
            to: result,
            nestingContext: nestingContext,
            presentationRole: presentationRole,
            theme: theme
        )
        return result
    }

    static func makeThematicBreakImage(theme: QuillTheme) -> UIImage {
        let size = CGSize(width: 10000, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            theme.thematicBreak.color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
