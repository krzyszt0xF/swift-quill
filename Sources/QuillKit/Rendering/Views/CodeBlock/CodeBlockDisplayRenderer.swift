import UIKit

@MainActor
enum CodeBlockDisplayRenderer {
    static func makeAttributedString(from code: String) -> NSAttributedString {
        NSAttributedString(
            string: code,
            attributes: CodeBlockTextStyle.makeAttributes()
        )
    }

    static func makeAttributedString(
        from highlightedCode: HighlightedCodeSnapshot,
        code: String
    ) -> NSAttributedString {
        let displayCode = NSMutableAttributedString(
            attributedString: highlightedCode.makeAttributedString()
        )
        applyCodeBlockTypography(to: displayCode)

        let missingTrailingNewlines = max(
            0,
            code.trailingNewlineCount - displayCode.string.trailingNewlineCount
        )
        guard missingTrailingNewlines > 0 else { return displayCode }

        displayCode.append(NSAttributedString(
            string: String(repeating: "\n", count: missingTrailingNewlines),
            attributes: CodeBlockTextStyle.makeAttributes()
        ))
        return displayCode
    }
}

private extension CodeBlockDisplayRenderer {
    static func applyCodeBlockTypography(to attributedString: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributedString.length)
        guard fullRange.length > 0 else { return }

        attributedString.addAttributes(
            [
                .font: CodeBlockTextStyle.font,
                .paragraphStyle: CodeBlockTextStyle.paragraphStyle,
            ],
            range: fullRange
        )

        attributedString.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            guard value == nil else { return }
            attributedString.addAttribute(
                .foregroundColor,
                value: UIColor.label,
                range: range
            )
        }
    }
}

enum CodeBlockTextStyle {
    static let font = UIFont(name: "Menlo-Regular", size: 14)
        ?? .monospacedSystemFont(ofSize: 14, weight: .regular)

    @MainActor static let paragraphStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        return style
    }()

    @MainActor
    static func makeAttributes(
        foregroundColor: UIColor = .label
    ) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraphStyle,
        ]
    }
}

private extension String {
    var trailingNewlineCount: Int {
        reversed().prefix { $0 == "\n" }.count
    }
}
