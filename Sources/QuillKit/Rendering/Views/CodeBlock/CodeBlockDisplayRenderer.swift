import UIKit

@MainActor
enum CodeBlockDisplayRenderer {
    static func makeAttributedString(
        from code: String,
        theme: QuillTheme
    ) -> NSAttributedString {
        NSAttributedString(
            string: code,
            attributes: makeAttributes(theme: theme)
        )
    }

    static func makeAttributedString(
        from highlightedCode: HighlightedCodeSnapshot,
        code: String,
        theme: QuillTheme
    ) -> NSAttributedString {
        let displayCode = NSMutableAttributedString(
            attributedString: highlightedCode.makeAttributedString()
        )
        applyCodeBlockTypography(
            to: displayCode,
            theme: theme
        )

        let missingTrailingNewlines = max(
            0,
            code.trailingNewlineCount - displayCode.string.trailingNewlineCount
        )
        guard missingTrailingNewlines > 0 else { return displayCode }

        displayCode.append(NSAttributedString(
            string: String(repeating: "\n", count: missingTrailingNewlines),
            attributes: makeAttributes(theme: theme)
        ))
        return displayCode
    }
}

private extension CodeBlockDisplayRenderer {
    static func applyCodeBlockTypography(
        to attributedString: NSMutableAttributedString,
        theme: QuillTheme
    ) {
        let fullRange = NSRange(location: 0, length: attributedString.length)
        guard fullRange.length > 0 else { return }

        attributedString.addAttributes(
            [
                .font: theme.codeBlock.font,
                .paragraphStyle: makeParagraphStyle(theme: theme),
            ],
            range: fullRange
        )

        attributedString.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            guard value == nil else { return }
            attributedString.addAttribute(
                .foregroundColor,
                value: theme.codeBlock.textColor,
                range: range
            )
        }
    }

    static func makeAttributes(theme: QuillTheme) -> [NSAttributedString.Key: Any] {
        [
            .font: theme.codeBlock.font,
            .foregroundColor: theme.codeBlock.textColor,
            .paragraphStyle: makeParagraphStyle(theme: theme),
        ]
    }

    static func makeParagraphStyle(theme: QuillTheme) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = theme.codeBlock.lineSpacing
        return style
    }
}

private extension String {
    var trailingNewlineCount: Int {
        reversed().prefix { $0 == "\n" }.count
    }
}
