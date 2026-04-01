import QuillCore
import QuillCoreTestSupport
@testable import QuillKit
import Testing
import UIKit

@Suite("AttributedStringBuilder Inline Formatting")
struct AttributedStringBuilderInlineFormattingTests {
    @Test("H1 produces font size 28 bold")
    func headingH1Font() {
        let result = makePipelineDocument(.heading(level: 1, content: [.text("Title")]))
        let resultFont = attributedStringBuilderFont(in: result)
        #expect(resultFont?.pointSize == 28)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("H6 produces font size 14 medium")
    func headingH6Font() {
        let result = makePipelineDocument(.heading(level: 6, content: [.text("Small")]))
        let resultFont = attributedStringBuilderFont(in: result)
        #expect(resultFont?.pointSize == 14)
    }

    @Test("H1-H6 all have different point sizes")
    func headingAllLevelsDistinct() {
        let sizes = (1...6).map { level -> CGFloat in
            let result = makePipelineDocument(.heading(level: level, content: [.text("H")]))
            return attributedStringBuilderFont(in: result)?.pointSize ?? 0
        }
        #expect(Set(sizes).count == 6)
    }

    @Test("strong applies bold trait")
    func boldTrait() {
        let result = makePipelineDocument(.paragraph(content: [.strong([.text("bold")])]))
        let resultFont = attributedStringBuilderFont(in: result)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("Emphasis applies italic trait")
    func italicTrait() {
        let result = makePipelineDocument(.paragraph(content: [.emphasis([.text("italic")])]))
        let resultFont = attributedStringBuilderFont(in: result)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
    }

    @Test("Strong wrapping emphasis composes both traits")
    func nestedBoldItalic() {
        let result = makePipelineDocument(.paragraph(content: [.strong([.emphasis([.text("both")])])]))
        let resultFont = attributedStringBuilderFont(in: result)
        let symbolicTraits = resultFont?.fontDescriptor.symbolicTraits ?? []
        #expect(symbolicTraits.contains(.traitBold))
        #expect(symbolicTraits.contains(.traitItalic))
    }

    @Test("Strikethrough applies strikethroughStyle attribute")
    func strikethroughAttribute() {
        let result = makePipelineDocument(.paragraph(content: [.strikethrough([.text("deleted")])]))
        let strikethroughStyle = result.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        #expect(strikethroughStyle == NSUnderlineStyle.single.rawValue)
    }

    @Test("Code produces monospace font with background")
    func inlineCodeFormatting() {
        let result = makePipelineDocument(.paragraph(content: [.code("let x")]))
        let resultFont = attributedStringBuilderFont(in: result)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
        let backgroundColor = result.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(backgroundColor != nil)
    }

    @Test("Link applies systemBlue foreground")
    func linkFormatting() {
        let result = makePipelineDocument(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))
        let linkForegroundColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(linkForegroundColor == UIColor.systemBlue)
    }

    @Test("Link applies single underline")
    func linkUnderlineStyle() {
        let result = makePipelineDocument(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))

        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
    }

    @Test("Link applies URL attribute for valid destination")
    func linkURLAttribute() {
        let result = makePipelineDocument(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))

        let linkURL = result.attribute(.link, at: 0, effectiveRange: nil) as? URL
        #expect(linkURL == URL(string: "https://example.com"))
    }

    @Test("Link stays inert for invalid destination")
    func invalidLinkDestinationIsInert() {
        let result = makePipelineDocument(.paragraph(content: [.link(destination: " ", children: [.text("click")])]))

        let linkForegroundColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int
        let linkURL = result.attribute(.link, at: 0, effectiveRange: nil) as? URL

        #expect(linkForegroundColor == UIColor.systemBlue)
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
        #expect(linkURL == nil)
    }

    @Test("Bare URL in text becomes tappable link")
    func bareURLInTextBecomesLink() {
        let result = makePipelineDocument(.paragraph(content: [.text("See https://developer.apple.com/documentation for docs")]))
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
        let result = makePipelineDocument(.paragraph(content: [.strong([.link(destination: "https://example.com", children: [.text("click")])])]))

        let resultFont = attributedStringBuilderFont(in: result)
        let linkForegroundColor = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        let underlineStyle = result.attribute(.underlineStyle, at: 0, effectiveRange: nil) as? Int

        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        #expect(linkForegroundColor == UIColor.systemBlue)
        #expect(underlineStyle == NSUnderlineStyle.single.rawValue)
    }

    @Test("Heading link keeps heading font and link styling")
    func headingLinkFormatting() {
        let result = makePipelineDocument(.heading(level: 2, content: [.link(destination: "https://example.com", children: [.text("Heading")])]))

        let resultFont = attributedStringBuilderFont(in: result)
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
        let result = makePipelineDocument(.unorderedList(items: items))
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
        let result = makePipelineDocument(blockquote)
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

    @Test("Blocks separated by newlines")
    func multipleBlocksSeparatedByNewlines() {
        let result = makePipelineDocument(
            .paragraph(content: [.text("one")]),
            .paragraph(content: [.text("two")])
        )
        #expect(result.string.contains("\n"))
    }
}
