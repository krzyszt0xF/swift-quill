import QuillCore
import UIKit

enum TextBlockAttributedStringRenderer {
    static func makeHeadingAttributedString(
        content: [Inline],
        level: Int,
        nestingContext: NestingContext,
        theme: QuillTheme
    ) -> NSAttributedString {
        let font = BlockStyleFactory.headingFont(level: level, theme: theme)
        let result = NSMutableAttributedString(
            attributedString: InlineContentRenderer.attributedString(
                for: content,
                baseFont: font,
                theme: theme
            )
        )
        let style = BlockStyleFactory.makeParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: theme.headingSpacingScaled,
            theme: theme
        )
        result.addAttribute(
            .foregroundColor,
            value: makeTextColor(nestingContext: nestingContext, theme: theme),
            range: NSRange(location: 0, length: result.length)
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }

    static func makeHTMLBlockAttributedString(
        nestingContext: NestingContext,
        rawHTML: String,
        theme: QuillTheme
    ) -> NSAttributedString {
        let font = BlockStyleFactory.bodyFont(theme: theme)
        let result = NSMutableAttributedString(string: rawHTML, attributes: [
            .font: font,
            .foregroundColor: makeTextColor(nestingContext: nestingContext, theme: theme),
        ])
        let style = BlockStyleFactory.makeParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: theme.blockSpacingScaled,
            theme: theme
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }

    static func makeParagraphAttributedString(
        content: [Inline],
        nestingContext: NestingContext,
        theme: QuillTheme
    ) -> NSAttributedString {
        let font = BlockStyleFactory.bodyFont(theme: theme)
        let result = NSMutableAttributedString(
            attributedString: InlineContentRenderer.attributedString(
                for: content,
                baseFont: font,
                theme: theme
            )
        )
        let style = BlockStyleFactory.makeParagraphStyle(
            nestingContext: nestingContext,
            paragraphSpacingBefore: theme.blockSpacingScaled,
            theme: theme
        )
        result.addAttribute(
            .foregroundColor,
            value: makeTextColor(nestingContext: nestingContext, theme: theme),
            range: NSRange(location: 0, length: result.length)
        )
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }
}

private extension TextBlockAttributedStringRenderer {
    static func makeTextColor(
        nestingContext: NestingContext,
        theme: QuillTheme
    ) -> UIColor {
        if nestingContext.blockquoteDepth > 0 {
            return theme.blockquote.textColor
        }
        return theme.body.textColor
    }
}
