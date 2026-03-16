import QuillCore
import UIKit

enum AttributedStringBuilder {
    static func build(from segment: RenderNode.FlowSegment) -> NSAttributedString {
        let result = NSMutableAttributedString()

        for (index, block) in segment.blocks.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(attributedString(for: block, nestingContext: .root))
        }

        return result
    }
}

extension NSAttributedString.Key {
    static let blockquoteDepth = NSAttributedString.Key("quill.blockquoteDepth")
    static let structuralMarker = NSAttributedString.Key("quill.structuralMarker")
}

// MARK: - Block Conversion

private extension AttributedStringBuilder {
    static func attributedString(for block: Block, nestingContext: NestingContext) -> NSAttributedString {
        switch block {
        case let .blockquote(children):
            return blockquoteAttributedString(children: children, nestingContext: nestingContext)
        case .codeBlock:
            return NSAttributedString()
        case let .heading(level, content):
            return headingAttributedString(level: level, content: content, nestingContext: nestingContext)
        case let .htmlBlock(rawHTML):
            return htmlBlockAttributedString(rawHTML: rawHTML, nestingContext: nestingContext)
        case let .orderedList(startIndex, items):
            return orderedListAttributedString(startIndex: startIndex, items: items, nestingContext: nestingContext)
        case let .paragraph(content):
            return paragraphAttributedString(content: content, nestingContext: nestingContext)
        case .table:
            return NSAttributedString()
        case .thematicBreak:
            return thematicBreakAttributedString()
        case let .unorderedList(items):
            return unorderedListAttributedString(items: items, nestingContext: nestingContext)
        }
    }

    static func blockquoteAttributedString(children: [Block], nestingContext: NestingContext) -> NSAttributedString {
        let nestedContext = NestingContext(
            blockquoteDepth: nestingContext.blockquoteDepth + 1,
            listLevel: 0
        )
        let result = NSMutableAttributedString()
        for (index, child) in children.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(attributedString(for: child, nestingContext: nestedContext))
        }

        let fullRange = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.blockquoteDepth, in: fullRange) { value, range, _ in
            if value == nil {
                result.addAttribute(.blockquoteDepth, value: nestedContext.blockquoteDepth, range: range)
            }
        }

        return result
    }

    static func headingAttributedString(level: Int, content: [Inline], nestingContext: NestingContext) -> NSAttributedString {
        let font = headingFont(level: level)
        let result = NSMutableAttributedString()
        for inline in content {
            result.append(attributedString(for: inline, baseFont: font))
        }

        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 12
        applyBlockquoteIndent(to: style, nestingContext: nestingContext)
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))

        return result
    }

    static func htmlBlockAttributedString(rawHTML: String, nestingContext: NestingContext) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 16)
        let result = NSMutableAttributedString(string: rawHTML, attributes: [
            .font: font,
            .foregroundColor: UIColor.label,
        ])

        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 8
        applyBlockquoteIndent(to: style, nestingContext: nestingContext)
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))

        return result
    }

    static func orderedListAttributedString(startIndex: UInt, items: [Block.ListItem], nestingContext: NestingContext) -> NSAttributedString {
        let bodyFont = UIFont.systemFont(ofSize: 16)
        let result = NSMutableAttributedString()

        for (index, item) in items.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            let marker = makeOrderedListMarker(
                checkbox: item.checkbox,
                itemIndex: index,
                startIndex: startIndex
            )
            let style = listParagraphStyle(level: nestingContext.listLevel, marker: marker, bodyFont: bodyFont)
            applyBlockquoteIndent(to: style, nestingContext: nestingContext)

            let itemResult = NSMutableAttributedString(string: marker, attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.label,
                .paragraphStyle: style,
                .structuralMarker: true,
            ])

            let childContext = NestingContext(
                blockquoteDepth: nestingContext.blockquoteDepth,
                listLevel: nestingContext.listLevel + 1
            )
            for (childIndex, child) in item.children.enumerated() {
                if childIndex == 0, case let .paragraph(content) = child {
                    for inline in content {
                        itemResult.append(attributedString(for: inline, baseFont: bodyFont))
                    }
                    itemResult.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: itemResult.length))
                } else {
                    itemResult.append(NSAttributedString(string: "\n"))
                    itemResult.append(attributedString(for: child, nestingContext: childContext))
                }
            }

            result.append(itemResult)
        }

        return result
    }

    static func paragraphAttributedString(content: [Inline], nestingContext: NestingContext) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: 16)
        let result = NSMutableAttributedString()
        for inline in content {
            result.append(attributedString(for: inline, baseFont: font))
        }

        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = 8
        applyBlockquoteIndent(to: style, nestingContext: nestingContext)
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))

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

    static func thematicBreakAttributedString() -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = thematicBreakImage
        attachment.bounds = CGRect(x: 0, y: 0, width: 10000, height: 1)

        let result = NSMutableAttributedString(attachment: attachment)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacingBefore = 8
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))

        return result
    }

    static func unorderedListAttributedString(items: [Block.ListItem], nestingContext: NestingContext) -> NSAttributedString {
        let bodyFont = UIFont.systemFont(ofSize: 16)
        let result = NSMutableAttributedString()

        let bulletChar: String
        switch nestingContext.listLevel {
        case 0: bulletChar = "+"
        case 1: bulletChar = "-"
        default: bulletChar = "*"
        }

        for (index, item) in items.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            let marker = makeUnorderedListMarker(
                bullet: bulletChar,
                checkbox: item.checkbox
            )
            let style = listParagraphStyle(level: nestingContext.listLevel, marker: marker, bodyFont: bodyFont)
            applyBlockquoteIndent(to: style, nestingContext: nestingContext)

            let itemResult = NSMutableAttributedString(string: marker, attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.label,
                .paragraphStyle: style,
                .structuralMarker: true,
            ])

            let childContext = NestingContext(
                blockquoteDepth: nestingContext.blockquoteDepth,
                listLevel: nestingContext.listLevel + 1
            )
            for (childIndex, child) in item.children.enumerated() {
                if childIndex == 0, case let .paragraph(content) = child {
                    for inline in content {
                        itemResult.append(attributedString(for: inline, baseFont: bodyFont))
                    }
                    itemResult.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: itemResult.length))
                } else {
                    itemResult.append(NSAttributedString(string: "\n"))
                    itemResult.append(attributedString(for: child, nestingContext: childContext))
                }
            }

            result.append(itemResult)
        }

        return result
    }

    static func makeOrderedListMarker(
        checkbox: Block.Checkbox?,
        itemIndex: Int,
        startIndex: UInt
    ) -> String {
        let prefix = "\(Int(startIndex) + itemIndex)."
        guard let checkbox else {
            return "\(prefix)\t"
        }
        return "\(prefix) \(makeTaskListMarker(for: checkbox))\t"
    }

    static func makeTaskListMarker(for checkbox: Block.Checkbox) -> String {
        switch checkbox {
        case .checked:
            return "[x]"
        case .unchecked:
            return "[ ]"
        }
    }

    static func makeUnorderedListMarker(
        bullet: String,
        checkbox: Block.Checkbox?
    ) -> String {
        guard let checkbox else {
            return "\(bullet)\t"
        }
        return "\(makeTaskListMarker(for: checkbox))\t"
    }
}

// MARK: - Inline Conversion

private extension AttributedStringBuilder {
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
            result.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: result.length))
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
}

// MARK: - Helpers

private extension AttributedStringBuilder {
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

    struct NestingContext {
        let blockquoteDepth: Int
        let listLevel: Int

        static let root = NestingContext(blockquoteDepth: 0, listLevel: 0)
    }

    static func applyBlockquoteIndent(to style: NSMutableParagraphStyle, nestingContext: NestingContext) {
        guard nestingContext.blockquoteDepth > 0 else {
            return
        }

        let indent = CGFloat(nestingContext.blockquoteDepth) * 16
        style.headIndent += indent
        style.firstLineHeadIndent += indent
    }

    static func headingFont(level: Int) -> UIFont {
        switch level {
        case 1:
            return .systemFont(ofSize: 28, weight: .bold)
        case 2:
            return .systemFont(ofSize: 24, weight: .bold)
        case 3:
            return .systemFont(ofSize: 20, weight: .semibold)
        case 4:
            return .systemFont(ofSize: 18, weight: .semibold)
        case 5:
            return .systemFont(ofSize: 16, weight: .medium)
        case 6:
            return .systemFont(ofSize: 14, weight: .medium)
        default:
            return .systemFont(ofSize: 16)
        }
    }

    static func listParagraphStyle(level: Int, marker: String, bodyFont: UIFont) -> NSMutableParagraphStyle {
        let baseIndent = CGFloat(level) * 24
        let markerWidth = (marker as NSString).size(withAttributes: [.font: bodyFont]).width
        let indent = baseIndent + markerWidth

        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = baseIndent
        style.headIndent = indent
        style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
        style.defaultTabInterval = indent
        style.paragraphSpacingBefore = 4
        return style
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
