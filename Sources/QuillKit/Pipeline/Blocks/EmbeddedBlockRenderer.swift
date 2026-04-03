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

        let result = NSMutableAttributedString(attachment: attachment)
        let style = BlockStyleFactory.makePresentationRoleParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: 8,
            presentationRole: presentationRole
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }

    static func makeOpenCodeFenceAttributedString(
        code: String,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole = .regularBlock
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: code, attributes: [
            .font: BlockStyleFactory.monospaceFont(),
            .foregroundColor: UIColor.label,
        ])
        let style = BlockStyleFactory.makePresentationRoleParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: 8,
            presentationRole: presentationRole
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
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

        let result = NSMutableAttributedString(attachment: attachment)
        let style = BlockStyleFactory.makePresentationRoleParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: 8,
            presentationRole: presentationRole
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
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

        let result = NSMutableAttributedString(string: lines.joined(separator: "\n"), attributes: [
            .font: BlockStyleFactory.monospaceFont(),
            .foregroundColor: UIColor.label,
        ])
        let style = BlockStyleFactory.makePresentationRoleParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: 8,
            presentationRole: presentationRole
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
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
    static let thematicBreakImage: UIImage = {
        let size = CGSize(width: 10000, height: 1)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.separator.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }()
}
