import QuillCore
import UIKit

enum BlockAttributedStringRenderer {
    static func build(from blocks: [Block]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let renderContext = RenderContext(
            highlightStore: nil,
            rendersAttachments: false
        )

        for (index, block) in blocks.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(makeAttributedString(
                for: block,
                nestingContext: .root,
                renderContext: renderContext
            ))
        }

        return result
    }

    static func makeAttributedString(
        for block: Block,
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> NSAttributedString {
        switch block {
        case let .blockquote(children):
            return makeBlockquoteAttributedString(
                children: children,
                nestingContext: nestingContext,
                renderContext: renderContext
            )
        case let .codeBlock(_, code):
            return EmbeddedBlockRenderer.makeOpenCodeFenceAttributedString(
                code: code,
                nestingContext: nestingContext
            )
        case let .heading(level, content):
            return makeHeadingAttributedString(
                content: content,
                level: level,
                nestingContext: nestingContext
            )
        case let .htmlBlock(rawHTML):
            return makeHTMLBlockAttributedString(
                nestingContext: nestingContext,
                rawHTML: rawHTML
            )
        case let .orderedList(startIndex, items):
            return ListPlainRenderer.buildOrderedListAttributedString(
                items: items,
                nestingContext: nestingContext,
                renderContext: renderContext,
                startIndex: startIndex
            )
        case let .paragraph(content):
            return makeParagraphAttributedString(
                content: content,
                nestingContext: nestingContext
            )
        case let .table(_, header, rows):
            return EmbeddedBlockRenderer.makeTableFallbackAttributedString(
                header: header,
                rows: rows,
                nestingContext: nestingContext
            )
        case .thematicBreak:
            return EmbeddedBlockRenderer.makeThematicBreakAttributedString()
        case let .unorderedList(items):
            return ListPlainRenderer.buildUnorderedListAttributedString(
                items: items,
                nestingContext: nestingContext,
                renderContext: renderContext
            )
        }
    }

    static func makeBlockquoteAttributedString(
        children: [BlockNode],
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> NSAttributedString {
        let nestedContext = nestingContext.incrementingBlockquoteDepth()
        let result = NSMutableAttributedString()

        for (index, child) in children.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(makeAttributedString(
                for: child.block,
                nestingContext: nestedContext,
                renderContext: renderContext
            ))
        }

        AttributedStringAttributeFormatter.applyBlockquoteDepth(
            to: result,
            depth: nestedContext.blockquoteDepth
        )
        return result
    }

    static func makeHeadingAttributedString(
        content: [Inline],
        level: Int,
        nestingContext: NestingContext
    ) -> NSAttributedString {
        let font = BlockStyleFactory.headingFont(level: level)
        let result = NSMutableAttributedString(
            attributedString: InlineContentRenderer.attributedString(for: content, baseFont: font)
        )
        let style = BlockStyleFactory.makeParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: 12
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }

    static func makeHTMLBlockAttributedString(
        nestingContext: NestingContext,
        rawHTML: String
    ) -> NSAttributedString {
        let font = BlockStyleFactory.bodyFont()
        let result = NSMutableAttributedString(string: rawHTML, attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
        ])
        let style = BlockStyleFactory.makeParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: 8
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }

    static func makeParagraphAttributedString(
        content: [Inline],
        nestingContext: NestingContext
    ) -> NSAttributedString {
        let font = BlockStyleFactory.bodyFont()
        let result = NSMutableAttributedString(
            attributedString: InlineContentRenderer.attributedString(for: content, baseFont: font)
        )
        let style = BlockStyleFactory.makeParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: 8
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }
}
