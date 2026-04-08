import QuillCore
import UIKit

enum InlineContentRenderer {
    static func attributedString(
        for inlines: [Inline],
        baseFont: UIFont,
        theme: QuillTheme
    ) -> NSAttributedString {
        attributedString(
            for: inlines,
            context: FontContext(
                baseFont: baseFont,
                theme: theme
            )
        )
    }

    static func plainText(from inlines: [Inline]) -> String {
        inlines.map { plainText(from: $0) }.joined()
    }
}

private extension InlineContentRenderer {
    struct FontContext {
        let baseFont: UIFont
        let theme: QuillTheme
        var traits: UIFontDescriptor.SymbolicTraits = []

        func adding(trait: UIFontDescriptor.SymbolicTraits) -> FontContext {
            FontContext(
                baseFont: baseFont,
                theme: theme,
                traits: traits.union(trait)
            )
        }

        var bodyFont: UIFont {
            traits.isEmpty ? baseFont : baseFont.withTraits(traits)
        }

        var monospaceFont: UIFont {
            let pointSize = max(1, baseFont.pointSize + theme.inline.fontSizeOffset)
            let monospaceFont = theme.codeBlock.font.withSize(pointSize)
            return traits.isEmpty ? monospaceFont : monospaceFont.withTraits(traits)
        }
    }

    static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func attributedString(
        for inline: Inline,
        context: FontContext
    ) -> NSAttributedString {
        switch inline {
        case let .code(text):
            return NSAttributedString(string: text, attributes: [
                .font: context.monospaceFont,
                .backgroundColor: context.theme.inline.backgroundColor,
                .foregroundColor: context.theme.inline.textColor,
            ])
        case let .emphasis(children):
            return attributedString(
                for: children,
                context: context.adding(trait: .traitItalic)
            )
        case let .image(_, _, alt):
            let text = alt.isEmpty ? "image" : plainText(from: alt)
            return NSAttributedString(string: "[\(text)]", attributes: [
                .font: context.bodyFont,
                .foregroundColor: context.theme.image.altTextColor,
            ])
        case .inlineHTML:
            return NSAttributedString()
        case .lineBreak:
            return NSAttributedString(string: "\n")
        case let .link(destination, children):
            return makeLinkAttributedString(
                destination: destination,
                children: children,
                context: context
            )
        case let .strikethrough(children):
            let result = NSMutableAttributedString(
                attributedString: attributedString(
                    for: children,
                    context: context
                )
            )
            result.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: NSRange(location: 0, length: result.length)
            )
            return result
        case let .strong(children):
            return attributedString(
                for: children,
                context: context.adding(trait: .traitBold)
            )
        case let .text(string):
            return makeTextAttributedString(
                string: string,
                context: context
            )
        }
    }

    static func attributedString(
        for inlines: [Inline],
        context: FontContext
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for inline in inlines {
            result.append(attributedString(for: inline, context: context))
        }

        return result
    }

    static func makeLinkAttributedString(
        destination: String,
        children: [Inline],
        context: FontContext
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            attributedString: attributedString(
                for: children,
                context: context
            )
        )
        let fullRange = NSRange(location: 0, length: result.length)
        result.addAttribute(.foregroundColor, value: context.theme.link.color, range: fullRange)
        result.addAttribute(
            .underlineStyle,
            value: context.theme.link.underlineStyle.rawValue,
            range: fullRange
        )

        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDestination.isEmpty == false,
           let url = URL(string: trimmedDestination) {
            result.addAttribute(.link, value: url, range: fullRange)
        }

        return result
    }

    static func makeTextAttributedString(
        string: String,
        context: FontContext
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(string: string, attributes: [
            .font: context.bodyFont,
            .foregroundColor: context.theme.body.textColor,
        ])
        guard
            string.contains("://") ||
                string.contains("www.") ||
                string.contains("@")
        else {
            return result
        }

        let fullRange = NSRange(location: 0, length: result.length)

        linkDetector?.enumerateMatches(in: string, options: [], range: fullRange) { match, _, _ in
            guard let match,
                  let url = match.url else {
                return
            }

            result.addAttribute(.foregroundColor, value: context.theme.link.color, range: match.range)
            result.addAttribute(
                .underlineStyle,
                value: context.theme.link.underlineStyle.rawValue,
                range: match.range
            )
            result.addAttribute(.link, value: url, range: match.range)
        }

        return result
    }

    static func plainText(from inline: Inline) -> String {
        switch inline {
        case let .emphasis(children),
            let .link(_, children),
            let .strikethrough(children),
            let .strong(children):
            return plainText(from: children)
        case let .image(_, _, alt):
            return plainText(from: alt)
        case .inlineHTML:
            return ""
        case .lineBreak:
            return " "
        case let .code(text):
            return text
        case let .text(string):
            return string
        }
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let combined = fontDescriptor.symbolicTraits.union(traits)
        guard let descriptor = fontDescriptor.withSymbolicTraits(combined) else {
            return self
        }

        return UIFont(descriptor: descriptor, size: 0)
    }
}
