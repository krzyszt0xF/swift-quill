import QuillCore
import QuillCoreTestSupport
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

    @Test("Link applies single underline")
    func linkUnderlineStyle() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))
        )

        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
    }

    @Test("Link applies URL attribute for valid destination")
    func linkURLAttribute() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))
        )

        let linkURL = result.attribute(.link, at: 0, effectiveRange: nil) as? URL
        #expect(linkURL == URL(string: "https://example.com"))
    }

    @Test("Link stays inert for invalid destination")
    func invalidLinkDestinationIsInert() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.link(destination: " ", children: [.text("click")])]))
        )

        let linkForegroundColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        let linkURL = result.attribute(.link, at: 0, effectiveRange: nil) as? URL

        #expect(linkForegroundColor == UIColor.systemBlue)
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
        #expect(linkURL == nil)
    }

    @Test("Bare URL in text becomes tappable link")
    func bareURLInTextBecomesLink() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.text("See https://developer.apple.com/documentation for docs")]))
        )
        let linkIndex = (result.string as NSString).range(of: "https://developer.apple.com/documentation").location

        let linkForegroundColor = result.attribute(.foregroundColor, at: linkIndex, effectiveRange: nil) as? UIColor
        let underlineStyle = result.attribute(.underlineStyle, at: linkIndex, effectiveRange: nil) as? Int
        let linkURL = result.attribute(.link, at: linkIndex, effectiveRange: nil) as? URL

        #expect(linkForegroundColor == UIColor.systemBlue)
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
        #expect(linkURL == URL(string: "https://developer.apple.com/documentation"))
    }

    @Test("Bold link keeps bold trait and link styling")
    func boldLinkFormatting() {
        let result = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.strong([.link(destination: "https://example.com", children: [.text("click")])])]))
        )

        let resultFont = font(in: result)
        let linkForegroundColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int

        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        #expect(linkForegroundColor == UIColor.systemBlue)
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
    }

    @Test("Heading link keeps heading font and link styling")
    func headingLinkFormatting() {
        let result = AttributedStringBuilder.build(
            from: segment(.heading(level: 2, content: [.link(destination: "https://example.com", children: [.text("Heading")])]))
        )

        let resultFont = font(in: result)
        let linkForegroundColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        let linkURL = result.attribute(.link, at: 0, effectiveRange: nil) as? URL

        #expect(resultFont?.pointSize == 24)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        #expect(linkForegroundColor == UIColor.systemBlue)
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
        #expect(linkURL == URL(string: "https://example.com"))
    }

    @Test("List item link keeps link styling")
    func listItemLinkFormatting() {
        let items = [
            makeItem(.paragraph(content: [.link(destination: "https://example.com", children: [.text("item")])])),
        ]
        let result = AttributedStringBuilder.build(from: segment(.unorderedList(items: items)))
        let linkIndex = (result.string as NSString).range(of: "item").location

        let linkForegroundColor = result.attribute(.foregroundColor, at: linkIndex, effectiveRange: nil) as? UIColor
        let underlineStyle = result.attribute(.underlineStyle, at: linkIndex, effectiveRange: nil) as? Int
        let linkURL = result.attribute(.link, at: linkIndex, effectiveRange: nil) as? URL

        #expect(linkForegroundColor == UIColor.systemBlue)
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
        #expect(linkURL == URL(string: "https://example.com"))
    }

    @Test("Blockquote link keeps link styling and blockquote depth")
    func blockquoteLinkFormatting() {
        let blockquote = makeBlockquote(
            .paragraph(content: [.link(destination: "https://example.com", children: [.text("quoted")])])
        )
        let result = AttributedStringBuilder.build(from: segment(blockquote))
        let linkIndex = (result.string as NSString).range(of: "quoted").location

        let linkForegroundColor = result.attribute(.foregroundColor, at: linkIndex, effectiveRange: nil) as? UIColor
        let underlineStyle = result.attribute(.underlineStyle, at: linkIndex, effectiveRange: nil) as? Int
        let linkURL = result.attribute(.link, at: linkIndex, effectiveRange: nil) as? URL
        let blockquoteDepth = result.attribute(.blockquoteDepth, at: linkIndex, effectiveRange: nil) as? Int

        #expect(linkForegroundColor == UIColor.systemBlue)
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
        #expect(linkURL == URL(string: "https://example.com"))
        #expect(blockquoteDepth == 1)
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
            makeItem(.paragraph(content: [.text("alpha")])),
            makeItem(.paragraph(content: [.text("beta")])),
        ]
        let result = AttributedStringBuilder.build(from: segment(.unorderedList(items: items)))
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
        let result = AttributedStringBuilder.build(from: segment(.orderedList(startIndex: 1, items: items)))
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
            makeItem(.paragraph(content: [.text("a")])),
            makeItem(.paragraph(content: [.text("b")])),
        ]
        let result = AttributedStringBuilder.build(from: segment(.orderedList(startIndex: 3, items: items)))
        #expect(result.string.contains("3."))
        #expect(result.string.contains("4."))
    }

    @Test("Task list renders checkbox marker")
    func taskListMarker() {
        let items = [
            makeItem(checkbox: .checked, .paragraph(content: [.text("done")])),
            makeItem(checkbox: .unchecked, .paragraph(content: [.text("pending")])),
        ]
        let result = AttributedStringBuilder.build(from: segment(.unorderedList(items: items)))

        #expect(result.string.contains("[x]\t"))
        #expect(result.string.contains("[ ]\t"))
    }

    // MARK: - Blockquote Tests

    @Test("Blockquote has greater indentation than plain text")
    func blockquoteIndentation() {
        let blockquote = makeBlockquote(.paragraph(content: [.text("quoted")]))
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
        let nestedBlockquote = makeBlockquote(.paragraph(content: [.text("deep")]))
        let outerBlockquote = makeBlockquote(.paragraph(content: [.text("shallow")]), nestedBlockquote)
        let result = AttributedStringBuilder.build(from: segment(outerBlockquote))

        let shallowRange = (result.string as NSString).range(of: "shallow")
        let deepRange = (result.string as NSString).range(of: "deep")

        let shallowIndent = (result.attribute(.paragraphStyle, at: shallowRange.location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0
        let deepIndent = (result.attribute(.paragraphStyle, at: deepRange.location, effectiveRange: nil) as? NSParagraphStyle)?.headIndent ?? 0

        #expect(deepIndent > shallowIndent)
    }

    @Test("Blockquote carries blockquoteDepth custom attribute")
    func blockquoteDepthAttribute() {
        let blockquote = makeBlockquote(.paragraph(content: [.text("quoted")]))
        let result = AttributedStringBuilder.build(from: segment(blockquote))

        let quotedRange = (result.string as NSString).range(of: "quoted")
        let blockquoteDepth = result.attribute(.blockquoteDepth, at: quotedRange.location, effectiveRange: nil) as? Int
        #expect(blockquoteDepth == 1)
    }

    // MARK: - Structural Marker Tests

    @Test("Unordered list has structuralMarker on bullet+tab characters")
    func unorderedListStructuralMarker() {
        let items = [
            makeItem(.paragraph(content: [.text("alpha")])),
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
            makeItem(.paragraph(content: [.text("first")])),
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
            makeItem(checkbox: .checked, .paragraph(content: [.text("first")])),
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
        let blockquote = makeBlockquote(.paragraph(content: [.text("quoted")]))
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

    // MARK: - Document Building Tests

    @Test("Paragraph-only document produces one fragment per block")
    func documentParagraphOnly() {
        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .paragraph(content: [.text("World")]),
        ]
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: makeNodes(blocks), frozenCount: blocks.count)

        #expect(fragments.count == 2)
        #expect(fragments[0].attributedString.string.contains("Hello"))
        #expect(fragments[1].attributedString.string.contains("World"))
    }

    @Test("Closed code block produces CodeBlockAttachment fragment")
    func documentClosedCodeBlock() {
        let blocks: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("After")]),
        ]
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: makeNodes(blocks), frozenCount: blocks.count)

        #expect(fragments.count == 3)

        var foundCodeBlockAttachment = false
        fragments[1].attributedString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: fragments[1].attributedString.length)
        ) { value, _, _ in
            if value is CodeBlockAttachment { foundCodeBlockAttachment = true }
        }
        #expect(foundCodeBlockAttachment)
    }

    @Test("Open code fence renders as plain monospace text")
    func documentOpenCodeFence() {
        let blocks: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: makeNodes(blocks), frozenCount: 1)

        #expect(fragments.count == 2)
        #expect(fragments[1].attributedString.string.contains("let x = 1"))

        var foundCodeBlockAttachment = false
        fragments[1].attributedString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: fragments[1].attributedString.length)
        ) { value, _, _ in
            if value is CodeBlockAttachment { foundCodeBlockAttachment = true }
        }
        #expect(foundCodeBlockAttachment == false)

        let resultFont = font(in: fragments[1].attributedString)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
    }

    @Test("Table fallback renders visible plain text with pipe separators")
    func documentTableFallback() {
        let header = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Name")]),
            Block.TableCell(content: [.text("Age")]),
        ])
        let rows = [
            Block.TableRow(cells: [
                Block.TableCell(content: [.text("Alice")]),
                Block.TableCell(content: [.text("30")]),
            ]),
        ]
        let blocks: [Block] = [
            .table(columnAlignments: [nil, nil], header: header, rows: rows),
        ]
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: makeNodes(blocks), frozenCount: blocks.count)

        #expect(fragments.count == 1)

        let text = fragments[0].attributedString.string
        #expect(text.contains("Name"))
        #expect(text.contains("Age"))
        #expect(text.contains("Alice"))
        #expect(text.contains("30"))
        #expect(text.contains("|"))
    }

    @Test("Blockquote depth propagates in document fragments")
    func documentBlockquoteDepth() {
        let blocks: [Block] = [
            makeBlockquote(makeBlockquote(.paragraph(content: [.text("deep")]))),
        ]
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: makeNodes(blocks), frozenCount: blocks.count)

        #expect(fragments.count == 1)

        let deepRange = (fragments[0].attributedString.string as NSString).range(of: "deep")
        let depth = fragments[0].attributedString.attribute(.blockquoteDepth, at: deepRange.location, effectiveRange: nil) as? Int
        #expect(depth == 2)
    }

    @Test("Empty input produces no fragments")
    func documentEmptyInput() {
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: [], frozenCount: 0)
        #expect(fragments.isEmpty)
    }

    @Test("buildDocument concatenates fragments with newline separators")
    func buildDocumentConcatenation() {
        let blocks: [Block] = [
            .paragraph(content: [.text("one")]),
            .paragraph(content: [.text("two")]),
        ]
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: makeNodes(blocks), frozenCount: blocks.count)
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        #expect(document.string.contains("one"))
        #expect(document.string.contains("two"))
        #expect(document.string.contains("\n"))
    }

    @Test("buildDocument stamps blockID attribute on each fragment range")
    func buildDocumentBlockIDAttribute() {
        let id1 = BlockIdentity(rawValue: 10)
        let id2 = BlockIdentity(rawValue: 11)
        let nodes = [
            BlockNode(block: .paragraph(content: [.text("alpha")]), id: id1),
            BlockNode(block: .paragraph(content: [.text("beta")]), id: id2),
        ]
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: nodes, frozenCount: nodes.count)
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        let alphaRange = (document.string as NSString).range(of: "alpha")
        let betaRange = (document.string as NSString).range(of: "beta")

        let alphaBlockID = document.attribute(.blockID, at: alphaRange.location, effectiveRange: nil) as? BlockIdentity
        let betaBlockID = document.attribute(.blockID, at: betaRange.location, effectiveRange: nil) as? BlockIdentity

        #expect(alphaBlockID == id1)
        #expect(betaBlockID == id2)
    }

    @Test("Each fragment has a unique blockID")
    func documentFragmentUniqueBlockIDs() {
        let blocks: [Block] = [
            .paragraph(content: [.text("a")]),
            .paragraph(content: [.text("b")]),
            .codeBlock(language: nil, code: "c"),
        ]
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: makeNodes(blocks), frozenCount: blocks.count)
        let ids = fragments.map(\.blockID)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Mixed document preserves paragraph-style spacing")
    func documentParagraphStyleSpacing() {
        let blocks: [Block] = [
            .heading(level: 1, content: [.text("Title")]),
            .paragraph(content: [.text("Body")]),
        ]
        let fragments = AttributedStringBuilder.buildDocumentFragments(from: makeNodes(blocks), frozenCount: blocks.count)
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        let titleRange = (document.string as NSString).range(of: "Title")
        let bodyRange = (document.string as NSString).range(of: "Body")

        let titleStyle = document.attribute(.paragraphStyle, at: titleRange.location, effectiveRange: nil) as? NSParagraphStyle
        let bodyStyle = document.attribute(.paragraphStyle, at: bodyRange.location, effectiveRange: nil) as? NSParagraphStyle

        #expect(titleStyle?.paragraphSpacingBefore ?? 0 > 0)
        #expect(bodyStyle?.paragraphSpacingBefore ?? 0 > 0)
    }

    @Test("Table fallback renders in flow segment build too")
    func tableFallbackInFlowBuild() {
        let header = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Col")]),
        ])
        let table = Block.table(columnAlignments: [nil], header: header, rows: [])
        let result = AttributedStringBuilder.build(from: segment(table))
        #expect(result.string.contains("Col"))
        #expect(result.string.contains("|"))
    }
}

private extension AttributedStringBuilderTests {
    func font(in string: NSAttributedString, at location: Int = 0) -> UIFont? {
        string.attribute(.font, at: location, effectiveRange: nil) as? UIFont
    }

    func segment(_ blocks: Block...) -> [Block] {
        Array(blocks)
    }
}
