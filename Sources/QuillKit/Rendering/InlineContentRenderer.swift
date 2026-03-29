import QuillCore
import UIKit

enum InlineContentRenderer {
    static func attributedString(for inline: Inline, baseFont: UIFont) -> NSAttributedString {
        switch inline {
        case let .code(text):
            let monoFont = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)
            return NSAttributedString(string: text, attributes: [
                .font: monoFont,
                .backgroundColor: UIColor.systemGray6,
                .foregroundColor: UIColor.label,
            ])
        case let .emphasis(children):
            let result = NSMutableAttributedString()
            for child in children {
                result.append(attributedString(for: child, baseFont: baseFont))
            }
            result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
                let current = (value as? UIFont) ?? baseFont
                result.addAttribute(.font, value: current.withTraits(.traitItalic), range: range)
            }
            return result
        case let .image(_, _, alt):
            let text = alt.isEmpty ? "image" : plainText(from: alt)
            return NSAttributedString(string: "[\(text)]", attributes: [
                .font: baseFont,
                .foregroundColor: UIColor.secondaryLabel,
            ])
        case .inlineHTML:
            return NSAttributedString()
        case .lineBreak:
            return NSAttributedString(string: "\n")
        case let .link(destination, children):
            let result = NSMutableAttributedString()
            for child in children {
                result.append(attributedString(for: child, baseFont: baseFont))
            }
            let fullRange = NSRange(location: 0, length: result.length)
            result.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: fullRange)
            result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)

            let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedDestination.isEmpty == false,
               let url = URL(string: trimmedDestination) {
                result.addAttribute(.link, value: url, range: fullRange)
            }

            return result
        case let .strikethrough(children):
            let result = NSMutableAttributedString()
            for child in children {
                result.append(attributedString(for: child, baseFont: baseFont))
            }
            result.addAttribute(
                .strikethroughStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: NSRange(location: 0, length: result.length)
            )
            return result
        case let .strong(children):
            let result = NSMutableAttributedString()
            for child in children {
                result.append(attributedString(for: child, baseFont: baseFont))
            }
            result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
                let current = (value as? UIFont) ?? baseFont
                result.addAttribute(.font, value: current.withTraits(.traitBold), range: range)
            }
            return result
        case let .text(string):
            return makeTextAttributedString(string: string, baseFont: baseFont)
        }
    }

    static func attributedString(for inlines: [Inline], baseFont: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for inline in inlines {
            result.append(attributedString(for: inline, baseFont: baseFont))
        }

        return result
    }

    static func plainText(from inlines: [Inline]) -> String {
        inlines.map { plainText(from: $0) }.joined()
    }

    static func plainText(from inline: Inline) -> String {
        switch inline {
        case let .code(text):
            return text
        case let .emphasis(children):
            return plainText(from: children)
        case let .image(_, _, alt):
            return plainText(from: alt)
        case .inlineHTML:
            return ""
        case .lineBreak:
            return " "
        case let .link(_, children):
            return plainText(from: children)
        case let .strikethrough(children):
            return plainText(from: children)
        case let .strong(children):
            return plainText(from: children)
        case let .text(string):
            return string
        }
    }
}

private extension InlineContentRenderer {
    static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func makeTextAttributedString(string: String, baseFont: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString(string: string, attributes: [
            .font: baseFont,
            .foregroundColor: UIColor.label,
        ])
        let fullRange = NSRange(location: 0, length: result.length)

        linkDetector?.enumerateMatches(in: string, options: [], range: fullRange) { match, _, _ in
            guard let match,
                  let url = match.url else {
                return
            }

            result.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: match.range)
            result.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            result.addAttribute(.link, value: url, range: match.range)
        }

        return result
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
