import QuillCore
import QuillCoreTestSupport
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@Suite("AttributedStringBuilder List and Structure", .tags(.rendering))
struct AttributedStringBuilderListTests {
    @Test("Unordered list has bullet markers")
    func unorderedListMarkers() {
        let items = [
            Block.ListItem(blocks: .paragraph(content: [.text("alpha")])),
            Block.ListItem(blocks: .paragraph(content: [.text("beta")])),
        ]
        let result = makePipelineDocument(.unorderedList(items: items))
        #expect(result.string.contains("+"))
        #expect(result.string.contains("alpha"))
        #expect(result.string.contains("beta"))
    }

    @Test("Ordered list has numbered markers")
    func orderedListMarkers() {
        let items = [
            Block.ListItem(blocks: .paragraph(content: [.text("first")])),
            Block.ListItem(blocks: .paragraph(content: [.text("second")])),
        ]
        let result = makePipelineDocument(.orderedList(startIndex: 1, items: items))
        #expect(result.string.contains("1."))
        #expect(result.string.contains("2."))
    }

    @Test("Nested list has greater indentation than parent")
    func nestedListIndentation() {
        let innerList = Block.unorderedList(items: [
            Block.ListItem(blocks: .paragraph(content: [.text("nested")]))
        ])
        let outerList = Block.unorderedList(items: [
            Block.ListItem(blocks: .paragraph(content: [.text("top")]), innerList)
        ])
        let result = makePipelineDocument(outerList)

        var outerIndent: CGFloat = 0
        var innerIndent: CGFloat = 0
        result.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            guard let paragraphStyle = value as? NSParagraphStyle else { return }
            if paragraphStyle.headIndent > innerIndent { innerIndent = paragraphStyle.headIndent }
            if outerIndent == 0 || paragraphStyle.headIndent < outerIndent { outerIndent = paragraphStyle.headIndent }
        }
        #expect(innerIndent > outerIndent)
    }

    @Test("Nested ordered list keeps greater indentation in built render fragments")
    func nestedOrderedListDocumentIndentation() {
        let blocks: [Block] = [
            .orderedList(startIndex: 1, items: [
                Block.ListItem(blocks:
                    .paragraph(content: [.text("Parse markdown into a stable block tree")]),
                    .orderedList(startIndex: 1, items: [
                        Block.ListItem(blocks: .paragraph(content: [
                            .text("Preserve nested ordered numbering")
                        ])),
                        Block.ListItem(blocks: .paragraph(content: [
                            .text("Keep wrapped lines aligned under the marker when they span more than one visual row")
                        ])
                        ),
                    ])
                ),
            ]),
        ]

        let fragments = AttributedStringBuilder.buildRenderFragments(
            from: blocks.makeNodes(),
            frozenCount: blocks.count
        )
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        let parentRange = (document.string as NSString).range(of: "Parse markdown into a stable block tree")
        let childRange = (document.string as NSString).range(of: "Preserve nested ordered numbering")

        let parentStyle = document.attribute(
            .paragraphStyle,
            at: parentRange.location,
            effectiveRange: nil) as? NSParagraphStyle
        let childStyle = document.attribute(
            .paragraphStyle,
            at: childRange.location,
            effectiveRange: nil) as? NSParagraphStyle

        #expect((childStyle?.headIndent ?? 0) > (parentStyle?.headIndent ?? 0))
        #expect((parentStyle?.headIndent ?? 0) > (parentStyle?.firstLineHeadIndent ?? 0))
        #expect((childStyle?.headIndent ?? 0) > (childStyle?.firstLineHeadIndent ?? 0))
    }

    @Test("Ordered list respects startIndex")
    func orderedListStartIndex() {
        let items = [
            Block.ListItem(blocks: .paragraph(content: [.text("a")])),
            Block.ListItem(blocks: .paragraph(content: [.text("b")])),
        ]
        let result = makePipelineDocument(.orderedList(startIndex: 3, items: items))
        #expect(result.string.contains("3."))
        #expect(result.string.contains("4."))
    }

    @Test("Task list renders checkbox marker")
    func taskListMarker() {
        let items = [
            Block.ListItem(checkbox: .checked, blocks: .paragraph(content: [.text("done")])),
            Block.ListItem(checkbox: .unchecked, blocks: .paragraph(content: [.text("pending")])),
        ]
        let result = makePipelineDocument(.unorderedList(items: items))

        #expect(result.string.contains("[x]\t"))
        #expect(result.string.contains("[ ]\t"))
    }

    @Test("Unfrozen ordered list preserves nested code block text")
    func orderedListNestedCodeBlock() {
        let items = [
            Block.ListItem(blocks:
                .paragraph(content: [.text("Intro")]),
                .codeBlock(language: "swift", code: "print(\"Hello\")\n")
            ),
        ]
        let result = makePipelineDocument(
            .orderedList(startIndex: 1, items: items),
            frozenCount: 0
        )

        #expect(result.string.contains("Intro"))
        #expect(result.string.contains("print(\"Hello\")"))
    }

    @Test("Unfrozen unordered list preserves nested code block text")
    func unorderedListNestedCodeBlock() {
        let items = [
            Block.ListItem(blocks:
                .paragraph(content: [.text("Intro")]),
                .codeBlock(language: nil, code: "code\n")
            ),
        ]
        let result = makePipelineDocument(
            .unorderedList(items: items),
            frozenCount: 0
        )

        #expect(result.string.contains("Intro"))
        #expect(result.string.contains("code"))
    }

    @Test("Blockquote has greater indentation than plain text")
    func blockquoteIndentation() {
        let blockquote = Block.makeBlockquote(.paragraph(content: [.text("quoted")]))
        let plainParagraph = Block.paragraph(content: [.text("plain")])
        let result = makePipelineDocument(blockquote, plainParagraph)

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
        let nestedBlockquote = Block.makeBlockquote(.paragraph(content: [.text("deep")]))
        let outerBlockquote = Block.makeBlockquote(.paragraph(content: [.text("shallow")]), nestedBlockquote)
        let result = makePipelineDocument(outerBlockquote)

        let shallowRange = (result.string as NSString).range(of: "shallow")
        let deepRange = (result.string as NSString).range(of: "deep")

        let shallowStyle = result.attribute(
            .paragraphStyle, at: shallowRange.location, effectiveRange: nil
        ) as? NSParagraphStyle
        let deepStyle = result.attribute(
            .paragraphStyle, at: deepRange.location, effectiveRange: nil
        ) as? NSParagraphStyle
        let shallowIndent = shallowStyle?.headIndent ?? 0
        let deepIndent = deepStyle?.headIndent ?? 0

        #expect(deepIndent > shallowIndent)
    }

    @Test("Blockquote carries blockquoteDepth custom attribute")
    func blockquoteDepthAttribute() {
        let blockquote = Block.makeBlockquote(.paragraph(content: [.text("quoted")]))
        let result = makePipelineDocument(blockquote)

        let quotedRange = (result.string as NSString).range(of: "quoted")
        let blockquoteDepth = result.attribute(.blockquoteDepth, at: quotedRange.location, effectiveRange: nil) as? Int
        #expect(blockquoteDepth == 1)
    }

    @Test("Blockquote preserves nested list markers and indentation")
    func blockquoteNestedListMarkersAndIndentation() {
        let quotedList = Block.makeBlockquote(.unorderedList(items: [
            Block.ListItem(blocks: .paragraph(content: [.text("quoted item")]))
        ]))
        let plainList = Block.unorderedList(items: [
            Block.ListItem(blocks: .paragraph(content: [.text("plain item")]))
        ])
        let result = makePipelineDocument(quotedList, plainList)

        #expect(result.string.contains("+\tquoted item"))
        #expect(result.string.contains("+\tplain item"))

        let quotedRange = (result.string as NSString).range(of: "quoted item")
        let plainRange = (result.string as NSString).range(of: "plain item")

        let quotedDepth = result.attribute(.blockquoteDepth, at: quotedRange.location, effectiveRange: nil) as? Int
        let quotedStyle = result.attribute(.paragraphStyle, at: quotedRange.location, effectiveRange: nil) as? NSParagraphStyle
        let plainStyle = result.attribute(.paragraphStyle, at: plainRange.location, effectiveRange: nil) as? NSParagraphStyle

        #expect(quotedDepth == 1)
        #expect((quotedStyle?.headIndent ?? 0) > (plainStyle?.headIndent ?? 0))
    }

    @Test("Unordered list has structuralMarker on bullet+tab characters")
    func unorderedListStructuralMarker() {
        let items = [
            Block.ListItem(blocks: .paragraph(content: [.text("alpha")])),
        ]
        let result = makePipelineDocument(.unorderedList(items: items))

        let markerString = "+\t"
        let markerRange = NSRange(location: 0, length: markerString.count)
        let hasMarker = result.attribute(.structuralMarker, at: 0, effectiveRange: nil) as? Bool
        #expect(hasMarker == true)

        var markerAttributeRange = NSRange()
        let fullRange = NSRange(location: 0, length: result.length)
        result.attribute(.structuralMarker, at: 0, longestEffectiveRange: &markerAttributeRange, in: fullRange)
        #expect(markerAttributeRange.length == markerRange.length)

        let textStart = markerString.count
        let textMarker = result.attribute(.structuralMarker, at: textStart, effectiveRange: nil) as? Bool
        #expect(textMarker == nil)
    }

    @Test("Ordered list has structuralMarker on number+dot+tab characters")
    func orderedListStructuralMarker() {
        let items = [
            Block.ListItem(blocks: .paragraph(content: [.text("first")])),
        ]
        let result = makePipelineDocument(.orderedList(startIndex: 1, items: items))

        let markerString = "1.\t"
        let hasMarker = result.attribute(.structuralMarker, at: 0, effectiveRange: nil) as? Bool
        #expect(hasMarker == true)

        var markerAttributeRange = NSRange()
        let fullRange = NSRange(location: 0, length: result.length)
        result.attribute(.structuralMarker, at: 0, longestEffectiveRange: &markerAttributeRange, in: fullRange)
        #expect(markerAttributeRange.length == markerString.count)

        let textStart = markerString.count
        let textMarker = result.attribute(.structuralMarker, at: textStart, effectiveRange: nil) as? Bool
        #expect(textMarker == nil)
    }

    @Test("Task list has structuralMarker on checkbox marker characters")
    func taskListStructuralMarker() {
        let items = [
            Block.ListItem(checkbox: .checked, blocks: .paragraph(content: [.text("first")])),
        ]
        let result = makePipelineDocument(.unorderedList(items: items))

        let markerString = "[x]\t"
        let hasMarker = result.attribute(.structuralMarker, at: 0, effectiveRange: nil) as? Bool
        #expect(hasMarker == true)

        var markerAttributeRange = NSRange()
        let fullRange = NSRange(location: 0, length: result.length)
        result.attribute(.structuralMarker, at: 0, longestEffectiveRange: &markerAttributeRange, in: fullRange)
        #expect(markerAttributeRange.length == markerString.count)

        let textStart = markerString.count
        let textMarker = result.attribute(.structuralMarker, at: textStart, effectiveRange: nil) as? Bool
        #expect(textMarker == nil)
    }

    @Test("Heading does NOT have structuralMarker")
    func headingNoStructuralMarker() {
        let result = makePipelineDocument(.heading(level: 1, content: [.text("Title")]))

        var hasStructuralMarker = false
        result.enumerateAttribute(.structuralMarker, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value != nil { hasStructuralMarker = true }
        }
        #expect(hasStructuralMarker == false)
    }

    @Test("Blockquote does NOT have structuralMarker")
    func blockquoteNoStructuralMarker() {
        let blockquote = Block.makeBlockquote(.paragraph(content: [.text("quoted")]))
        let result = makePipelineDocument(blockquote)

        var hasStructuralMarker = false
        result.enumerateAttribute(.structuralMarker, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value != nil { hasStructuralMarker = true }
        }
        #expect(hasStructuralMarker == false)
    }

    @Test("Thematic break produces NSTextAttachment")
    func thematicBreakPresent() {
        let result = makePipelineDocument(.thematicBreak)
        #expect(result.length > 0)

        var hasAttachment = false
        result.enumerateAttribute(.attachment, in: NSRange(location: 0, length: result.length)) { value, _, _ in
            if value is NSTextAttachment { hasAttachment = true }
        }
        #expect(hasAttachment)
    }
}
