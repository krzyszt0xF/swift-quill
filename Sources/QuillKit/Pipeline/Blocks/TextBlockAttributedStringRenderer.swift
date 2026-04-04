import QuillCore
import UIKit

enum TextBlockAttributedStringRenderer {
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
