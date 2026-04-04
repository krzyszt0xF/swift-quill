@testable import QuillCore
import QuillSharedTestSupport
import Testing

@Suite("StreamBuffer Code Fences and Thematic Breaks", .tags(.streaming))
struct StreamBufferCodeFenceThematicBreakTests {
    static let thematicBreakCases: [ThematicBreakTestCase] = [
        .init(input: "***\n", name: "Asterisks"),
        .init(input: "---\n", name: "Dashes"),
        .init(input: "___\n", name: "Underscores"),
    ]

    @Test("Backtick code fence with language")
    func backtickFenceWithLanguage() {
        var buffer = StreamBuffer()
        let events = buffer.append("```swift\nlet x = 1\n```\n")
        #expect(events == [
            .startCodeBlock(language: "swift"),
            .codeBlockText("let x = 1\n"),
            .endCodeBlock,
        ])
    }

    @Test("Backtick code fence without language")
    func backtickFenceNoLanguage() {
        var buffer = StreamBuffer()
        let events = buffer.append("```\nhello\n```\n")
        #expect(events == [
            .startCodeBlock(language: nil),
            .codeBlockText("hello\n"),
            .endCodeBlock,
        ])
    }

    @Test("Variable-length fence requires matching count to close")
    func variableLengthFence() {
        var buffer = StreamBuffer()
        let events = buffer.append("````\n```\nstill code\n````\n")
        #expect(events == [
            .startCodeBlock(language: nil),
            .codeBlockText("```\n"),
            .codeBlockText("still code\n"),
            .endCodeBlock,
        ])
    }

    @Test("Tilde fence open and close")
    func tildeFence() {
        var buffer = StreamBuffer()
        let events = buffer.append("~~~\ncode here\n~~~\n")
        #expect(events == [
            .startCodeBlock(language: nil),
            .codeBlockText("code here\n"),
            .endCodeBlock,
        ])
    }

    @Test("Tilde fence not closed by backticks")
    func tildeFenceNotClosedByBackticks() {
        var buffer = StreamBuffer()
        let events = buffer.append("~~~\ncode\n```\n~~~\n")
        #expect(events == [
            .startCodeBlock(language: nil),
            .codeBlockText("code\n"),
            .codeBlockText("```\n"),
            .endCodeBlock,
        ])
    }

    @Test("Finalize closes open code fence")
    func finalizeCodeFence() {
        var buffer = StreamBuffer()
        _ = buffer.append("```python\nprint('hi')\n")
        let events = buffer.finalize()
        #expect(events == [.endCodeBlock])
    }

    @Test("Thematic break variants", arguments: thematicBreakCases)
    func thematicBreakVariants(_ testCase: ThematicBreakTestCase) {
        var buffer = StreamBuffer()
        let events = buffer.append(testCase.input)
        #expect(events == [.thematicBreak])
    }

    @Test("Adversarial: code fence split mid-language")
    func adversarialFenceSplit() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("```sw")
        #expect(events1.isEmpty)

        let events2 = buffer.append("ift\ncode\n```\n")
        #expect(events2 == [
            .startCodeBlock(language: "swift"),
            .codeBlockText("code\n"),
            .endCodeBlock,
        ])
    }

    @Test("Partial code line streams before newline inside fence")
    func partialCodeLineStreamsBeforeNewline() {
        var buffer = StreamBuffer()

        let events1 = buffer.append("```\npri")
        #expect(events1 == [.startCodeBlock(language: nil), .codeBlockText("pri")])

        let events2 = buffer.append("nt\n")
        #expect(events2 == [.codeBlockText("nt\n")])
    }

    @Test("Previewed full code line still emits trailing newline")
    func previewedFullCodeLineStillEmitsTrailingNewline() {
        var buffer = StreamBuffer()

        let events1 = buffer.append("```\nprint")
        #expect(events1 == [.startCodeBlock(language: nil), .codeBlockText("print")])

        let events2 = buffer.append("\n")
        #expect(events2 == [.codeBlockText("\n")])
    }

    @Test("Adversarial: thematic break split")
    func adversarialThematicBreakSplit() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("--")
        #expect(events1.isEmpty)

        let events2 = buffer.append("-\n")
        #expect(events2 == [.thematicBreak])
    }

    @Test("Adversarial: short fence prefix waits for disambiguation")
    func adversarialShortFencePrefix() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("``")
        #expect(events1.isEmpty)

        let events2 = buffer.append("`\ncode\n```\n")
        #expect(events2 == [
            .startCodeBlock(language: nil),
            .codeBlockText("code\n"),
            .endCodeBlock,
        ])
    }

    @Test("Paragraph interrupted by code fence")
    func paragraphInterruptedByFence() {
        var buffer = StreamBuffer()
        let events = buffer.append("Text\n```\ncode\n```\n")
        #expect(events == [
            .startParagraph, .text("Text"),
            .endParagraph,
            .startCodeBlock(language: nil),
            .codeBlockText("code\n"),
            .endCodeBlock,
        ])
    }

    @Test("Code fence preserves blank lines inside")
    func codeFencePreservesBlankLines() {
        var buffer = StreamBuffer()
        let events = buffer.append("```\nline1\n\nline2\n```\n")
        #expect(events == [
            .startCodeBlock(language: nil),
            .codeBlockText("line1\n"),
            .codeBlockText("\n"),
            .codeBlockText("line2\n"),
            .endCodeBlock,
        ])
    }
}

struct ThematicBreakTestCase: Sendable {
    let input: String
    let name: String
}

extension ThematicBreakTestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}
