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
        let resultFont = font(in: result)
        #expect(resultFont?.pointSize == 28)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("H6 produces font size 14 medium")
    func headingH6Font() {
        let result = AttributedStringBuilder.build(from: segment(.heading(level: 6, content: [.text("Small")])))
        let resultFont = font(in: result)
        #expect(resultFont?.pointSize == 14)
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
    func boldTrait() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.strong([.text("bold")])]))
        )
        let resultFont = font(in: result)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("Emphasis applies italic trait")
    func italicTrait() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.emphasis([.text("italic")])]))
        )
        let resultFont = font(in: result)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
    }

    @Test("Strong wrapping emphasis composes both traits")
    func nestedBoldItalic() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.strong([.emphasis([.text("both")])])]))
        )
        let resultFont = font(in: result)
        let symbolicTraits = resultFont?.fontDescriptor.symbolicTraits ?? []
        #expect(symbolicTraits.contains(.traitBold))
        #expect(symbolicTraits.contains(.traitItalic))
    }

    @Test("Strikethrough applies strikethroughStyle attribute")
    func strikethroughAttribute() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.strikethrough([.text("deleted")])]))
        )
        let strikethroughStyle = result.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        #expect(strikethroughStyle == NSUnderlineStyle.single.rawValue)
    }

    @Test("Code produces monospace font with background")
    func inlineCodeFormatting() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.code("let x")]))
        )
        let resultFont = font(in: result)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
        let backgroundColor = result.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(backgroundColor != nil)
    }

    @Test("Link applies systemBlue foreground")
    func linkFormatting() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))
        )
        let linkForegroundColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(linkForegroundColor == UIColor.systemBlue)
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
        let innerList = Block.unorderedList(items: [
            Block.ListItem(children: [.paragraph(content: [.text("nested")])])
        ])
        let outerList = Block.unorderedList(items: [
            Block.ListItem(children: [.paragraph(content: [.text("top")]), innerList])
        ])
        let result = AttributedStringBuilder.build(from: segment(outerList))

        var outerIndent: CGFloat = 0
        var innerIndent: CGFloat = 0
        result.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard let paragraphStyle = value as? NSParagraphStyle else { return }
            if paragraphStyle.headIndent > innerIndent { innerIndent = paragraphStyle.headIndent }
            if outerIndent == 0 || paragraphStyle.headIndent < outerIndent { outerIndent = paragraphStyle.headIndent }
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

    @Test("Task list renders checkbox marker")
    func taskListMarker() {
        let items = [
            Block.ListItem(checkbox: .checked, children: [.paragraph(content: [.text("done")])]),
            Block.ListItem(checkbox: .unchecked, children: [.paragraph(content: [.text("pending")])]),
        ]
        let result = AttributedStringBuilder.build(from: segment(.unorderedList(items: items)))

        #expect(result.string.contains("[x]\t"))
        #expect(result.string.contains("[ ]\t"))
    }

    // MARK: - Blockquote Tests

    @Test("Blockquote has greater indentation than plain text")
    func blockquoteIndentation() {
        let blockquote = Block.blockquote(children: [.paragraph(content: [.text("quoted")])])
        let plainParagraph = Block.paragraph(content: [.text("plain")])
        let result = AttributedStringBuilder.build(from: segment(blockquote, plainParagraph))

        var blockquoteIndent: CGFloat = 0
        var plainIndent: CGFloat = 0

        let blockquoteRange = (result.string as NSString).range(of: "quoted")
        if let paragraphStyle = result.attribute(.paragraphStyle, at: blockquoteRange.location, effectiveRange: nil) as? NSParagraphStyle {
            blockquoteIndent = paragraphStyle.headIndent
        }
        let plainRange = (result.string as NSString).range(of: "plain")
        if let paragraphStyle = result.attribute(.paragraphStyle, at: plainRange.location, effectiveRange: nil) as? NSParagraphStyle {
            plainIndent = paragraphStyle.headIndent
        }
        #expect(blockquoteIndent > plainIndent)
    }

    @Test("Nested blockquote has greater indent than single")
    func nestedBlockquoteIndentation() {
        let nestedBlockquote = Block.blockquote(children: [.paragraph(content: [.text("deep")])])
        let outerBlockquote = Block.blockquote(children: [.paragraph(content: [.text("shallow")]), nestedBlockquote])
        let result = AttributedStringBuilder.build(from: segment(outerBlockquote))

        let shallowRange = (result.string as NSString).range(of: "shallow")
        let deepRange = (result.string as NSString).range(of: "deep")

        let shallowIndent = (result.attribute(.paragraphStyle, at: shallowRange.location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0
        let deepIndent = (result.attribute(.paragraphStyle, at: deepRange.location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0

        #expect(deepIndent > shallowIndent)
    }

    @Test("Blockquote carries blockquoteDepth custom attribute")
    func blockquoteDepthAttribute() {
        let blockquote = Block.blockquote(children: [.paragraph(content: [.text("quoted")])])
        let result = AttributedStringBuilder.build(from: segment(blockquote))

        let quotedRange = (result.string as NSString).range(of: "quoted")
        let blockquoteDepth = result.attribute(.blockquoteDepth, at: quotedRange.location, effectiveRange: nil) as? Int
        #expect(blockquoteDepth == 1)
    }

    // MARK: - Structural Marker Tests

    @Test("Unordered list has structuralMarker on bullet+tab characters")
    func unorderedListStructuralMarker() {
        let items = [
            Block.ListItem(children: [.paragraph(content: [.text("alpha")])]),
        ]
        let result = AttributedStringBuilder.build(from: segment(.unorderedList(items: items)))

        let markerString = "+\t"
        let markerRange = NSRange(location: 0, length: markerString.count)
        let hasMarker = result.attribute(.structuralMarker, at: 0, effectiveRange: nil) as? Bool
        #expect(hasMarker == true)

        var markerAttributeRange = NSRange()
        result.attribute(.structuralMarker, at: 0, longestEffectiveRange: &markerAttributeRange, in: NSRange(location: 0, length: result.length))
        #expect(markerAttributeRange.length == markerRange.length)

        let textStart = markerString.count
        let textMarker = result.attribute(.structuralMarker, at: textStart, effectiveRange: nil) as? Bool
        #expect(textMarker == nil)
    }

    @Test("Ordered list has structuralMarker on number+dot+tab characters")
    func orderedListStructuralMarker() {
        let items = [
            Block.ListItem(children: [.paragraph(content: [.text("first")])]),
        ]
        let result = AttributedStringBuilder.build(from: segment(.orderedList(startIndex: 1, items: items)))

        let markerString = "1.\t"
        let hasMarker = result.attribute(.structuralMarker, at: 0, effectiveRange: nil) as? Bool
        #expect(hasMarker == true)

        var markerAttributeRange = NSRange()
        result.attribute(.structuralMarker, at: 0, longestEffectiveRange: &markerAttributeRange, in: NSRange(location: 0, length: result.length))
        #expect(markerAttributeRange.length == markerString.count)

        let textStart = markerString.count
        let textMarker = result.attribute(.structuralMarker, at: textStart, effectiveRange: nil) as? Bool
        #expect(textMarker == nil)
    }

    @Test("Task list has structuralMarker on checkbox marker characters")
    func taskListStructuralMarker() {
        let items = [
            Block.ListItem(checkbox: .checked, children: [.paragraph(content: [.text("first")])]),
        ]
        let result = AttributedStringBuilder.build(from: segment(.unorderedList(items: items)))

        let markerString = "[x]\t"
        let hasMarker = result.attribute(.structuralMarker, at: 0, effectiveRange: nil) as? Bool
        #expect(hasMarker == true)

        var markerAttributeRange = NSRange()
        result.attribute(.structuralMarker, at: 0, longestEffectiveRange: &markerAttributeRange, in: NSRange(location: 0, length: result.length))
        #expect(markerAttributeRange.length == markerString.count)

        let textStart = markerString.count
        let textMarker = result.attribute(.structuralMarker, at: textStart, effectiveRange: nil) as? Bool
        #expect(textMarker == nil)
    }

    @Test("Heading does NOT have structuralMarker")
    func headingNoStructuralMarker() {
        let result = AttributedStringBuilder.build(from: segment(.heading(level: 1, content: [.text("Title")])))

        var hasStructuralMarker = false
        result.enumerateAttribute(.structuralMarker, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value != nil { hasStructuralMarker = true }
        }
        #expect(hasStructuralMarker == false)
    }

    @Test("Blockquote does NOT have structuralMarker")
    func blockquoteNoStructuralMarker() {
        let blockquote = Block.blockquote(children: [.paragraph(content: [.text("quoted")])])
        let result = AttributedStringBuilder.build(from: segment(blockquote))

        var hasStructuralMarker = false
        result.enumerateAttribute(.structuralMarker, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value != nil { hasStructuralMarker = true }
        }
        #expect(hasStructuralMarker == false)
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
