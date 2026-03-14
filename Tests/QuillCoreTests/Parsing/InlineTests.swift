import QuillCore
import Testing

@Suite("Inline Tests")
struct InlineTests {

    // MARK: - Text

    static let textCases: [InlineTestCase] = [
        InlineTestCase(
            name: "Plain text",
            markdown: "Hello world",
            expected: [.text("Hello world")]
        ),
        InlineTestCase(
            name: "Text with special characters",
            markdown: "Angle < bracket > and & ampersand",
            expected: [.text("Angle < bracket > and & ampersand")]
        ),
    ]

    @Test("Text inlines", arguments: textCases)
    func textInlines(_ testCase: InlineTestCase) {
        let inlines = extractFirstParagraphContent(from: testCase.markdown)
        #expect(inlines == testCase.expected)
    }

    // MARK: - Strong

    static let strongCases: [InlineTestCase] = [
        InlineTestCase(
            name: "Bold text",
            markdown: "**bold**",
            expected: [.strong([.text("bold")])]
        ),
        InlineTestCase(
            name: "Bold with surrounding text",
            markdown: "before **bold** after",
            expected: [.text("before "), .strong([.text("bold")]), .text(" after")]
        ),
    ]

    @Test("Strong inlines", arguments: strongCases)
    func strongInlines(_ testCase: InlineTestCase) {
        let inlines = extractFirstParagraphContent(from: testCase.markdown)
        #expect(inlines == testCase.expected)
    }

    // MARK: - Emphasis

    static let emphasisCases: [InlineTestCase] = [
        InlineTestCase(
            name: "Italic text",
            markdown: "*italic*",
            expected: [.emphasis([.text("italic")])]
        ),
        InlineTestCase(
            name: "Italic with surrounding text",
            markdown: "normal *italic* normal",
            expected: [.text("normal "), .emphasis([.text("italic")]), .text(" normal")]
        ),
    ]

    @Test("Emphasis inlines", arguments: emphasisCases)
    func emphasisInlines(_ testCase: InlineTestCase) {
        let inlines = extractFirstParagraphContent(from: testCase.markdown)
        #expect(inlines == testCase.expected)
    }

    // MARK: - Strikethrough

    static let strikethroughCases: [InlineTestCase] = [
        InlineTestCase(
            name: "Strikethrough text",
            markdown: "~~struck~~",
            expected: [.strikethrough([.text("struck")])]
        ),
        InlineTestCase(
            name: "Strikethrough in sentence",
            markdown: "not ~~struck~~ out",
            expected: [.text("not "), .strikethrough([.text("struck")]), .text(" out")]
        ),
    ]

    @Test("Strikethrough inlines", arguments: strikethroughCases)
    func strikethroughInlines(_ testCase: InlineTestCase) {
        let inlines = extractFirstParagraphContent(from: testCase.markdown)
        #expect(inlines == testCase.expected)
    }

    // MARK: - Code

    static let codeCases: [InlineTestCase] = [
        InlineTestCase(
            name: "Inline code",
            markdown: "`code`",
            expected: [.code("code")]
        ),
        InlineTestCase(
            name: "Code in sentence",
            markdown: "Use `let` to declare",
            expected: [.text("Use "), .code("let"), .text(" to declare")]
        ),
    ]

    @Test("Code inlines", arguments: codeCases)
    func codeInlines(_ testCase: InlineTestCase) {
        let inlines = extractFirstParagraphContent(from: testCase.markdown)
        #expect(inlines == testCase.expected)
    }

    // MARK: - Links

    static let linkCases: [InlineTestCase] = [
        InlineTestCase(
            name: "Explicit link",
            markdown: "[Example](https://example.com)",
            expected: [.link(destination: "https://example.com", children: [.text("Example")])]
        ),
        InlineTestCase(
            name: "Autolink",
            markdown: "<https://example.com>",
            expected: [.link(destination: "https://example.com", children: [.text("https://example.com")])]
        ),
    ]

    @Test("Links", arguments: linkCases)
    func links(_ testCase: InlineTestCase) {
        let inlines = extractFirstParagraphContent(from: testCase.markdown)
        #expect(inlines == testCase.expected)
    }

    // MARK: - Nested Inlines

    static let nestedCases: [InlineTestCase] = [
        InlineTestCase(
            name: "Bold containing italic",
            markdown: "***bold and italic***",
            // CommonMark spec: emphasis wraps strong for *** delimiter
            expected: [.emphasis([.strong([.text("bold and italic")])])]
        ),
        InlineTestCase(
            name: "Bold with nested emphasis",
            markdown: "**bold *and italic* text**",
            expected: [.strong([
                .text("bold "),
                .emphasis([.text("and italic")]),
                .text(" text"),
            ])]
        ),
    ]

    @Test("Nested inlines", arguments: nestedCases)
    func nestedInlines(_ testCase: InlineTestCase) {
        let inlines = extractFirstParagraphContent(from: testCase.markdown)
        #expect(inlines == testCase.expected)
    }

    // MARK: - Line Break

    @Test("Soft break renders as space")
    func softBreak() {
        // A single newline in source is a soft break -- rendered as space
        let inlines = extractFirstParagraphContent(from: "line one\nline two")
        #expect(inlines == [.text("line one"), .text(" "), .text("line two")])
    }

    @Test("Hard break renders as lineBreak")
    func hardBreak() {
        // Two trailing spaces + newline = hard break
        let inlines = extractFirstParagraphContent(from: "line one  \nline two")
        #expect(inlines == [.text("line one"), .lineBreak, .text("line two")])
    }

    // MARK: - Mixed Inlines

    @Test("Mixed inline content")
    func mixedInlines() {
        let inlines = extractFirstParagraphContent(from: "Hello **bold** and `code` with [link](https://x.com)")
        #expect(inlines == [
            .text("Hello "),
            .strong([.text("bold")]),
            .text(" and "),
            .code("code"),
            .text(" with "),
            .link(destination: "https://x.com", children: [.text("link")]),
        ])
    }
}

// MARK: - Test Case Type

struct InlineTestCase: Sendable {
    let name: String
    let markdown: String
    let expected: [Inline]
}

extension InlineTestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}

// MARK: - Helper

private func extractFirstParagraphContent(from markdown: String) -> [Inline]? {
    let blocks = MarkdownParser.live.parse(markdown)
    guard case let .paragraph(content) = blocks.first else {
        return nil
    }
    
    return content
}
