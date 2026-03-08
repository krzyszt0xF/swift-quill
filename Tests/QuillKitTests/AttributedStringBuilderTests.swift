import QuillCore
@testable import QuillKit
import Testing
import UIKit

@Suite("AttributedStringBuilder")
struct AttributedStringBuilderTests {

    // MARK: - Heading Tests

    @Test("H1 produces font size 28 bold")
    func headingH1Font() {
        let result = AttributedStringBuilder.build(from: segment(.heading(level: 1, content: [.text("Title")])))
        let f = font(in: result)
        #expect(f?.pointSize == 28)
        #expect(f?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("H6 produces font size 14 medium")
    func headingH6Font() {
        let result = AttributedStringBuilder.build(from: segment(.heading(level: 6, content: [.text("Small")])))
        let f = font(in: result)
        #expect(f?.pointSize == 14)
    }

    @Test("H1-H6 all have different point sizes")
    func headingAllLevelsDistinct() {
        let sizes = (1...6).map { level -> CGFloat in
            let result = AttributedStringBuilder.build(from: segment(.heading(level: level, content: [.text("H")])))
            return font(in: result)?.pointSize ?? 0
        }
        #expect(Set(sizes).count == 6)
    }

    // MARK: - Inline Style Tests

    @Test("strong applies bold trait")
    func boldText() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.strong([.text("bold")])]))
        )
        let f = font(in: result)
        #expect(f?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("Emphasis applies italic trait")
    func italicText() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.emphasis([.text("italic")])]))
        )
        let f = font(in: result)
        #expect(f?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
    }

    @Test("Strong wrapping emphasis composes both traits")
    func boldItalicNested() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.strong([.emphasis([.text("both")])])]))
        )
        let f = font(in: result)
        let traits = f?.fontDescriptor.symbolicTraits ?? []
        #expect(traits.contains(.traitBold))
        #expect(traits.contains(.traitItalic))
    }

    @Test("Strikethrough applies strikethroughStyle attribute")
    func strikethroughText() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.strikethrough([.text("deleted")])]))
        )
        let value = result.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        #expect(value == NSUnderlineStyle.single.rawValue)
    }

    @Test("Code produces monospace font with background")
    func inlineCode() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.code("let x")]))
        )
        let f = font(in: result)
        #expect(f?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
        let bg = result.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(bg != nil)
    }

    @Test("Link applies systemBlue foreground")
    func linkText() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))
        )
        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(color == UIColor.systemBlue)
    }

    // MARK: - Multi-Block Tests

    @Test("Blocks separated by newlines")
    func multipleBlocksSeparatedByNewlines() {
        let result = AttributedStringBuilder.build(
            from: segment(
                .paragraph(content: [.text("one")]),
                .paragraph(content: [.text("two")])
            )
        )
        #expect(result.string.contains("\n"))
    }

    // MARK: - List Tests

    @Test("Unordered list has bullet markers")
    func unorderedListMarkers() {
        let items = [
            Block.ListItem(children: [.paragraph(content: [.text("alpha")])]),
            Block.ListItem(children: [.paragraph(content: [.text("beta")])]),
        ]
        let result = AttributedStringBuilder.build(from: segment(.unorderedList(items: items)))
        #expect(result.string.contains("+"))
        #expect(result.string.contains("alpha"))
        #expect(result.string.contains("beta"))
    }

    @Test("Ordered list has numbered markers")
    func orderedListMarkers() {
        let items = [
            Block.ListItem(children: [.paragraph(content: [.text("first")])]),
            Block.ListItem(children: [.paragraph(content: [.text("second")])]),
        ]
        let result = AttributedStringBuilder.build(from: segment(.orderedList(startIndex: 1, items: items)))
        #expect(result.string.contains("1."))
        #expect(result.string.contains("2."))
    }

    @Test("Nested list has greater indentation than parent")
    func nestedListIndentation() {
        let inner = Block.unorderedList(items: [
            Block.ListItem(children: [.paragraph(content: [.text("nested")])])
        ])
        let outer = Block.unorderedList(items: [
            Block.ListItem(children: [.paragraph(content: [.text("top")]), inner])
        ])
        let result = AttributedStringBuilder.build(from: segment(outer))

        var outerIndent: CGFloat = 0
        var innerIndent: CGFloat = 0
        result.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard let style = value as? NSParagraphStyle else { return }
            if style.headIndent > innerIndent { innerIndent = style.headIndent }
            if outerIndent == 0 || style.headIndent < outerIndent { outerIndent = style.headIndent }
        }
        #expect(innerIndent > outerIndent)
    }

    @Test("Ordered list respects startIndex")
    func orderedListStartIndex() {
        let items = [
            Block.ListItem(children: [.paragraph(content: [.text("a")])]),
            Block.ListItem(children: [.paragraph(content: [.text("b")])]),
        ]
        let result = AttributedStringBuilder.build(from: segment(.orderedList(startIndex: 3, items: items)))
        #expect(result.string.contains("3."))
        #expect(result.string.contains("4."))
    }

    // MARK: - Blockquote Tests

    @Test("Blockquote has greater indentation than plain text")
    func blockquoteIndentation() {
        let bq = Block.blockquote(children: [.paragraph(content: [.text("quoted")])])
        let plain = Block.paragraph(content: [.text("plain")])
        let result = AttributedStringBuilder.build(from: segment(bq, plain))

        var bqIndent: CGFloat = 0
        var plainIndent: CGFloat = 0

        let bqRange = (result.string as NSString).range(of: "quoted")
        if let style = result.attribute(.paragraphStyle, at: bqRange.location, effectiveRange: nil) as? NSParagraphStyle {
            bqIndent = style.headIndent
        }
        let plainRange = (result.string as NSString).range(of: "plain")
        if let style = result.attribute(.paragraphStyle, at: plainRange.location, effectiveRange: nil) as? NSParagraphStyle {
            plainIndent = style.headIndent
        }
        #expect(bqIndent > plainIndent)
    }

    @Test("Nested blockquote has greater indent than single")
    func nestedBlockquoteIndentation() {
        let inner = Block.blockquote(children: [.paragraph(content: [.text("deep")])])
        let outer = Block.blockquote(children: [.paragraph(content: [.text("shallow")]), inner])
        let result = AttributedStringBuilder.build(from: segment(outer))

        let shallowRange = (result.string as NSString).range(of: "shallow")
        let deepRange = (result.string as NSString).range(of: "deep")

        let shallowIndent = (result.attribute(.paragraphStyle, at: shallowRange.location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0
        let deepIndent = (result.attribute(.paragraphStyle, at: deepRange.location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0

        #expect(deepIndent > shallowIndent)
    }

    @Test("Blockquote carries blockquoteDepth custom attribute")
    func blockquoteDepthAttribute() {
        let bq = Block.blockquote(children: [.paragraph(content: [.text("quoted")])])
        let result = AttributedStringBuilder.build(from: segment(bq))

        let range = (result.string as NSString).range(of: "quoted")
        let depth = result.attribute(.blockquoteDepth, at: range.location, effectiveRange: nil) as? Int
        #expect(depth == 1)
    }

    // MARK: - Thematic Break Tests

    @Test("Thematic break produces NSTextAttachment")
    func thematicBreakPresent() {
        let result = AttributedStringBuilder.build(from: segment(.thematicBreak))
        #expect(result.length > 0)

        var hasAttachment = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value is NSTextAttachment { hasAttachment = true }
        }
        #expect(hasAttachment)
    }
}

private extension AttributedStringBuilderTests {
    func font(in string: NSAttributedString, at location: Int = 0) -> UIFont? {
        string.attribute(.font, at: location, effectiveRange: nil) as? UIFont
    }

    func segment(_ blocks: Block...) -> RenderNode.FlowSegment {
        RenderNode.FlowSegment(blocks: Array(blocks))
    }
}
