@testable import QuillCore
import QuillSharedTestSupport
import Testing

@Suite("InlineParser", .tags(.parsing))
struct InlineParserTests {

    // MARK: - Plain Text

    @Test("Plain text with no markers")
    func plainText() {
        let result = InlineParser.parse("Hello world")
        #expect(result == [.text("Hello world")])
    }

    @Test("Long plain text stays as one text node")
    func longPlainText() {
        let input = String(repeating: "streaming markdown ", count: 64)
        let result = InlineParser.parse(input)
        #expect(result == [.text(input)])
    }

    // MARK: - Complete Spans

    @Test("Bold text")
    func bold() {
        let result = InlineParser.parse("**bold**")
        #expect(result == [.strong([.text("bold")])])
    }

    @Test("Italic text")
    func italic() {
        let result = InlineParser.parse("*italic*")
        #expect(result == [.emphasis([.text("italic")])])
    }

    @Test("Inline code")
    func inlineCode() {
        let result = InlineParser.parse("`code`")
        #expect(result == [.code("code")])
    }

    @Test("Strikethrough text")
    func strikethrough() {
        let result = InlineParser.parse("~~struck~~")
        #expect(result == [.strikethrough([.text("struck")])])
    }

    @Test("Link")
    func link() {
        let result = InlineParser.parse("[text](url)")
        #expect(result == [.link(destination: "url", children: [.text("text")])])
    }

    @Test("Link label keeps nested formatting")
    func linkLabelFormatting() {
        let result = InlineParser.parse("[**text**](url)")
        #expect(result == [.link(destination: "url", children: [.strong([.text("text")])])])
    }

    @Test("Image")
    func image() {
        let result = InlineParser.parse("![alt](url)")
        #expect(result == [.image(source: "url", title: nil, alt: [.text("alt")])])
    }

    @Test("Image alt keeps nested formatting")
    func imageAltFormatting() {
        let result = InlineParser.parse("![*alt*](url)")
        #expect(result == [.image(source: "url", title: nil, alt: [.emphasis([.text("alt")])])])
    }

    // MARK: - Nested Spans

    @Test("Bold with nested italic")
    func boldWithNestedItalic() {
        let result = InlineParser.parse("**bold *and italic***")
        #expect(result == [.strong([
            .text("bold "),
            .emphasis([.text("and italic")]),
        ])])
    }

    @Test("Italic with nested bold")
    func italicWithNestedBold() {
        let result = InlineParser.parse("*italic **bold** text*")
        #expect(result == [.emphasis([
            .text("italic "),
            .strong([.text("bold")]),
            .text(" text"),
        ])])
    }

    // MARK: - Mixed Content

    @Test("Mixed bold and italic and text")
    func mixedContent() {
        let result = InlineParser.parse("Hello **bold** and *italic* world")
        #expect(result == [
            .text("Hello "),
            .strong([.text("bold")]),
            .text(" and "),
            .emphasis([.text("italic")]),
            .text(" world"),
        ])
    }

    @Test("Mixed delimiters do not introduce empty text nodes")
    func mixedContentWithoutEmptyTextNodes() {
        let result = InlineParser.parse("start**bold**`code`[link](url)end")
        #expect(result == [
            .text("start"),
            .strong([.text("bold")]),
            .code("code"),
            .link(destination: "url", children: [.text("link")]),
            .text("end"),
        ])
    }

    @Test("Adjacent spans")
    func adjacentSpans() {
        let result = InlineParser.parse("**bold** *italic*")
        #expect(result == [
            .strong([.text("bold")]),
            .text(" "),
            .emphasis([.text("italic")]),
        ])
    }

    @Test("Multi-line joined text with bold span")
    func multiLineJoined() {
        let result = InlineParser.parse("Hello **bold continues here**")
        #expect(result == [
            .text("Hello "),
            .strong([.text("bold continues here")]),
        ])
    }

    // MARK: - Incomplete Spans (Markers Stripped)

    @Test("Incomplete bold strips markers")
    func incompleteBold() {
        let result = InlineParser.parse("**incomplete")
        #expect(result == [.text("incomplete")])
    }

    @Test("Incomplete italic strips markers")
    func incompleteItalic() {
        let result = InlineParser.parse("*incomplete")
        #expect(result == [.text("incomplete")])
    }

    @Test("Incomplete strikethrough strips markers")
    func incompleteStrikethrough() {
        let result = InlineParser.parse("~~incomplete")
        #expect(result == [.text("incomplete")])
    }

    @Test("Incomplete nested strips all markers")
    func incompleteNested() {
        let result = InlineParser.parse("**bold *and nested")
        #expect(result == [.text("bold and nested")])
    }

    @Test("Malformed opener does not swallow later valid span")
    func malformedOpenerKeepsLaterValidSpan() {
        let result = InlineParser.parse("**broken and *valid*")
        #expect(result == [
            .text("broken and "),
            .emphasis([.text("valid")]),
        ])
    }

    // MARK: - Speculative Code

    @Test("Unclosed backtick renders speculatively as code")
    func speculativeCode() {
        let result = InlineParser.parse("`unclosed code")
        #expect(result == [.code("unclosed code")])
    }

    // MARK: - Incomplete Links and Images

    @Test("Link with incomplete destination")
    func linkIncompleteDestination() {
        let result = InlineParser.parse("[text](partial")
        #expect(result == [.text("text")])
    }

    @Test("Link with no closing paren")
    func linkNoClosingParen() {
        let result = InlineParser.parse("[text](")
        #expect(result == [.text("text")])
    }

    @Test("Link with no destination at all")
    func linkNoDestination() {
        let result = InlineParser.parse("[text]")
        #expect(result == [.text("text")])
    }

    @Test("Image incomplete")
    func imageIncomplete() {
        let result = InlineParser.parse("![alt")
        #expect(result == [.text("alt")])
    }

    // MARK: - Edge Cases

    @Test("Lone asterisk stays as plain text")
    func loneAsterisk() {
        let result = InlineParser.parse("use * for multiplication")
        #expect(result == [.text("use * for multiplication")])
    }

    @Test("Empty bold")
    func emptyBold() {
        let result = InlineParser.parse("****")
        #expect(result == [.strong([])])
    }

    @Test("Empty input")
    func emptyInput() {
        let result = InlineParser.parse("")
        #expect(result == [])
    }

    @Test("Only spaces")
    func onlySpaces() {
        let result = InlineParser.parse("   ")
        #expect(result == [.text("   ")])
    }

    @Test("Code with backtick inside text")
    func codeWithSurroundingText() {
        let result = InlineParser.parse("Use `let` to declare")
        #expect(result == [.text("Use "), .code("let"), .text(" to declare")])
    }

    @Test("Bold then text then code")
    func boldThenTextThenCode() {
        let result = InlineParser.parse("**bold** and `code`")
        #expect(result == [
            .strong([.text("bold")]),
            .text(" and "),
            .code("code"),
        ])
    }

    @Test("Link with full URL")
    func linkWithFullURL() {
        let result = InlineParser.parse("[Example](https://example.com)")
        #expect(result == [.link(destination: "https://example.com", children: [.text("Example")])])
    }

    @Test("Image with full URL")
    func imageWithFullURL() {
        let result = InlineParser.parse("![logo](https://img.com/logo.png)")
        #expect(result == [.image(source: "https://img.com/logo.png", title: nil, alt: [.text("logo")])])
    }

    @Test("Text before and after link")
    func textBeforeAndAfterLink() {
        let result = InlineParser.parse("see [this](url) here")
        #expect(result == [
            .text("see "),
            .link(destination: "url", children: [.text("this")]),
            .text(" here"),
        ])
    }

    @Test("Incomplete bold with text before")
    func incompleteBoldWithTextBefore() {
        let result = InlineParser.parse("Hello **bold")
        #expect(result == [.text("Hello bold")])
    }

    @Test("Incomplete italic with text before")
    func incompleteItalicWithTextBefore() {
        let result = InlineParser.parse("Hello *italic")
        #expect(result == [.text("Hello italic")])
    }
}
