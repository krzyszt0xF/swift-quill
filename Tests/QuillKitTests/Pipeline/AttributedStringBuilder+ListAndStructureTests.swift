import QuillCore
import QuillCoreTestSupport
@testable import QuillKit
import Testing
import UIKit

@Suite("AttributedStringBuilder List and Structure")
struct AttributedStringBuilderListAndStructureTests {
    @Test("Unordered list has bullet markers")
    func unorderedListMarkers() {
        let items = [
            makeItem(.paragraph(content: [.text("alpha")])),
            makeItem(.paragraph(content: [.text("beta")])),
        ]
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(.unorderedList(items: items)))
        #expect(result.string.contains("+"))
        #expect(result.string.contains("alpha"))
        #expect(result.string.contains("beta"))
    }

    @Test("Ordered list has numbered markers")
    func orderedListMarkers() {
        let items = [
            makeItem(.paragraph(content: [.text("first")])),
            makeItem(.paragraph(content: [.text("second")])),
        ]
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(.orderedList(startIndex: 1, items: items)))
        #expect(result.string.contains("1."))
        #expect(result.string.contains("2."))
    }

    @Test("Nested list has greater indentation than parent")
    func nestedListIndentation() {
        let innerList = Block.unorderedList(items: [
            makeItem(.paragraph(content: [.text("nested")]))
        ])
        let outerList = Block.unorderedList(items: [
            makeItem(.paragraph(content: [.text("top")]), innerList)
        ])
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(outerList))

        var outerIndent: CGFloat = 0
        var innerIndent: CGFloat = 0
        result.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard let paragraphStyle = value as? NSParagraphStyle else { return }
            if paragraphStyle.headIndent > innerIndent { innerIndent = paragraphStyle.headIndent }
            if outerIndent == 0 || paragraphStyle.headIndent < outerIndent { outerIndent = paragraphStyle.headIndent }
        }
        #expect(innerIndent > outerIndent)
    }

    @Test("Nested ordered list keeps greater indentation in built document fragments")
    func nestedOrderedListDocumentIndentation() {
        let blocks: [Block] = [
            .orderedList(startIndex: 1, items: [
                makeItem(
                    .paragraph(content: [.text("Parse markdown into a stable block tree")]),
                    .orderedList(startIndex: 1, items: [
                        makeItem(.paragraph(content: [.text("Preserve nested ordered numbering")])),
                        makeItem(.paragraph(content: [.text("Keep wrapped lines aligned under the marker when they span more than one visual row in the narrow stream pane")])),
                    ])
                ),
            ]),
        ]

        let fragments = AttributedStringBuilder.buildRenderFragments(
            from: makeNodes(blocks),
            frozenCount: blocks.count
        )
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        let parentRange = (document.string as NSString).range(of: "Parse markdown into a stable block tree")
        let childRange = (document.string as NSString).range(of: "Preserve nested ordered numbering")

        let parentStyle = document.attribute(.paragraphStyle, at: parentRange.location, effectiveRange: nil) as? NSParagraphStyle
        let childStyle = document.attribute(.paragraphStyle, at: childRange.location, effectiveRange: nil) as? NSParagraphStyle

        #expect((childStyle?.headIndent ?? 0) > (parentStyle?.headIndent ?? 0))
        #expect((parentStyle?.headIndent ?? 0) > (parentStyle?.firstLineHeadIndent ?? 0))
        #expect((childStyle?.headIndent ?? 0) > (childStyle?.firstLineHeadIndent ?? 0))
    }

    @Test("Ordered list respects startIndex")
    func orderedListStartIndex() {
        let items = [
            makeItem(.paragraph(content: [.text("a")])),
            makeItem(.paragraph(content: [.text("b")])),
        ]
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(.orderedList(startIndex: 3, items: items)))
        #expect(result.string.contains("3."))
        #expect(result.string.contains("4."))
    }

    @Test("Task list renders checkbox marker")
    func taskListMarker() {
        let items = [
            makeItem(checkbox: .checked, .paragraph(content: [.text("done")])),
            makeItem(checkbox: .unchecked, .paragraph(content: [.text("pending")])),
        ]
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(.unorderedList(items: items)))

        #expect(result.string.contains("[x]\t"))
        #expect(result.string.contains("[ ]\t"))
    }

    @Test("Ordered list preserves nested code block text")
    func orderedListNestedCodeBlock() {
        let items = [
            makeItem(
                .paragraph(content: [.text("Intro")]),
                .codeBlock(language: "swift", code: "print(\"Hello\")\n")
            ),
        ]
        let result = AttributedStringBuilder.build(
            from: attributedStringBuilderSegments(.orderedList(startIndex: 1, items: items))
        )

        #expect(result.string.contains("Intro"))
        #expect(result.string.contains("print(\"Hello\")"))
    }

    @Test("Unordered list preserves nested code block text")
    func unorderedListNestedCodeBlock() {
        let items = [
            makeItem(
                .paragraph(content: [.text("Intro")]),
                .codeBlock(language: nil, code: "code\n")
            ),
        ]
        let result = AttributedStringBuilder.build(
            from: attributedStringBuilderSegments(.unorderedList(items: items))
        )

        #expect(result.string.contains("Intro"))
        #expect(result.string.contains("code"))
    }

    @Test("Blockquote has greater indentation than plain text")
    func blockquoteIndentation() {
        let blockquote = makeBlockquote(.paragraph(content: [.text("quoted")]))
        let plainParagraph = Block.paragraph(content: [.text("plain")])
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(blockquote, plainParagraph))

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
        let nestedBlockquote = makeBlockquote(.paragraph(content: [.text("deep")]))
        let outerBlockquote = makeBlockquote(.paragraph(content: [.text("shallow")]), nestedBlockquote)
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(outerBlockquote))

        let shallowRange = (result.string as NSString).range(of: "shallow")
        let deepRange = (result.string as NSString).range(of: "deep")

        let shallowIndent = (result.attribute(.paragraphStyle, at: shallowRange.location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0
        let deepIndent = (result.attribute(.paragraphStyle, at: deepRange.location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0

        #expect(deepIndent > shallowIndent)
    }

    @Test("Blockquote carries blockquoteDepth custom attribute")
    func blockquoteDepthAttribute() {
        let blockquote = makeBlockquote(.paragraph(content: [.text("quoted")]))
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(blockquote))

        let quotedRange = (result.string as NSString).range(of: "quoted")
        let blockquoteDepth = result.attribute(.blockquoteDepth, at: quotedRange.location, effectiveRange: nil) as? Int
        #expect(blockquoteDepth == 1)
    }

    @Test("Unordered list has structuralMarker on bullet+tab characters")
    func unorderedListStructuralMarker() {
        let items = [
            makeItem(.paragraph(content: [.text("alpha")])),
        ]
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(.unorderedList(items: items)))

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
            makeItem(.paragraph(content: [.text("first")])),
        ]
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(.orderedList(startIndex: 1, items: items)))

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
            makeItem(checkbox: .checked, .paragraph(content: [.text("first")])),
        ]
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(.unorderedList(items: items)))

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
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(.heading(level: 1, content: [.text("Title")])))

        var hasStructuralMarker = false
        result.enumerateAttribute(.structuralMarker, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value != nil { hasStructuralMarker = true }
        }
        #expect(hasStructuralMarker == false)
    }

    @Test("Blockquote does NOT have structuralMarker")
    func blockquoteNoStructuralMarker() {
        let blockquote = makeBlockquote(.paragraph(content: [.text("quoted")]))
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(blockquote))

        var hasStructuralMarker = false
        result.enumerateAttribute(.structuralMarker, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value != nil { hasStructuralMarker = true }
        }
        #expect(hasStructuralMarker == false)
    }

    @Test("Thematic break produces NSTextAttachment")
    func thematicBreakPresent() {
        let result = AttributedStringBuilder.build(from: attributedStringBuilderSegments(.thematicBreak))
        #expect(result.length > 0)

        var hasAttachment = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value is NSTextAttachment { hasAttachment = true }
        }
        #expect(hasAttachment)
    }
}
