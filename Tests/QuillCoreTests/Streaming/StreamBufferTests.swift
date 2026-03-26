@testable import QuillCore
import Testing

@Suite("StreamBuffer")
struct StreamBufferTests {
    // MARK: - Partial Line Accumulation

    @Test("Partial line accumulation across chunks")
    func partialLineAccumulation() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("hel")
        #expect(events1 == [.startParagraph, .text("hel")])

        let events2 = buffer.append("lo\n")
        #expect(events2 == [.text("lo")])
    }

    @Test("Empty chunk produces no events")
    func emptyChunk() {
        var buffer = StreamBuffer()
        let events = buffer.append("")
        #expect(events.isEmpty)
    }

    // MARK: - Paragraph Detection

    @Test("Blank line after paragraph emits endParagraph")
    func paragraphBoundary() {
        var buffer = StreamBuffer()
        let events = buffer.append("Hello world\n\n")
        #expect(events == [.startParagraph, .text("Hello world"), .endParagraph])
    }

    @Test("Two paragraphs separated by blank line")
    func twoParagraphs() {
        var buffer = StreamBuffer()
        let events = buffer.append("First\n\nSecond\n")
        #expect(events == [
            .startParagraph, .text("First"), .endParagraph,
            .startParagraph, .text("Second"),
        ])
    }

    @Test("Finalize closes open paragraph")
    func finalizeParagraph() {
        var buffer = StreamBuffer()
        _ = buffer.append("Open text\n")
        let events = buffer.finalize()
        #expect(events == [.endParagraph])
    }

    @Test("Multi-line paragraph accumulates text events")
    func multiLineParagraph() {
        var buffer = StreamBuffer()
        let events = buffer.append("Line one\nLine two\n\n")
        #expect(events == [
            .startParagraph, .text("Line one"),
            .text(" Line two"),
            .endParagraph,
        ])
    }

    // MARK: - Code Fence Detection

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

    // MARK: - Heading Detection

    @Test("ATX heading detection")
    func headingDetection() {
        var buffer = StreamBuffer()
        let events = buffer.append("## Title\n")
        #expect(events == [.startHeading(level: 2), .text("Title"), .endHeading])
    }

    @Test("H1 heading")
    func h1Heading() {
        var buffer = StreamBuffer()
        let events = buffer.append("# Hello\n")
        #expect(events == [.startHeading(level: 1), .text("Hello"), .endHeading])
    }

    @Test("H6 heading")
    func h6Heading() {
        var buffer = StreamBuffer()
        let events = buffer.append("###### Deep\n")
        #expect(events == [.startHeading(level: 6), .text("Deep"), .endHeading])
    }

    @Test("Seven hashes is not a heading")
    func sevenHashesNotHeading() {
        var buffer = StreamBuffer()
        let events = buffer.append("####### Not a heading\n\n")
        #expect(events.contains(.startParagraph))
    }

    // MARK: - Thematic Break Detection

    @Test("Dashes thematic break")
    func dashesThematicBreak() {
        var buffer = StreamBuffer()
        let events = buffer.append("---\n")
        #expect(events == [.thematicBreak])
    }

    @Test("Asterisks thematic break")
    func asterisksThematicBreak() {
        var buffer = StreamBuffer()
        let events = buffer.append("***\n")
        #expect(events == [.thematicBreak])
    }

    @Test("Underscores thematic break")
    func underscoresThematicBreak() {
        var buffer = StreamBuffer()
        let events = buffer.append("___\n")
        #expect(events == [.thematicBreak])
    }

    // MARK: - List Detection

    @Test("Unordered list item")
    func unorderedListItem() {
        var buffer = StreamBuffer()
        let events = buffer.append("- item\n\n")
        #expect(events == [
            .startList(ordered: false), .startListItem, .startParagraph, .text("item"),
            .endParagraph, .endListItem, .endList,
        ])
    }

    @Test("Multiple unordered list items")
    func multipleUnorderedItems() {
        var buffer = StreamBuffer()
        let events = buffer.append("- first\n- second\n\n")
        #expect(events == [
            .startList(ordered: false), .startListItem, .startParagraph, .text("first"),
            .endParagraph, .endListItem, .startListItem, .startParagraph, .text("second"),
            .endParagraph, .endListItem, .endList,
        ])
    }

    @Test("Nested unordered list emits nested list events")
    func nestedUnorderedList() {
        var buffer = StreamBuffer()
        let events = buffer.append("- outer\n  - inner\n- after\n\n")
        #expect(events == [
            .startList(ordered: false), .startListItem, .startParagraph, .text("outer"),
            .endParagraph, .startList(ordered: false), .startListItem, .startParagraph, .text("inner"),
            .endParagraph, .endListItem, .endList, .endListItem,
            .startListItem, .startParagraph, .text("after"),
            .endParagraph, .endListItem, .endList,
        ])
    }

    @Test("Ordered list item")
    func orderedListItem() {
        var buffer = StreamBuffer()
        let events = buffer.append("1. item\n\n")
        #expect(events == [
            .startList(ordered: true), .startListItem, .startParagraph, .text("item"),
            .endParagraph, .endListItem, .endList,
        ])
    }

    @Test("Task list item emits checked start event")
    func checkedTaskListItem() {
        var buffer = StreamBuffer()
        let events = buffer.append("- [x] done\n\n")
        #expect(events == [
            .startList(ordered: false), .startTaskListItem(checkbox: .checked), .startParagraph, .text("done"),
            .endParagraph, .endListItem, .endList,
        ])
    }

    @Test("Task list item emits unchecked start event")
    func uncheckedTaskListItem() {
        var buffer = StreamBuffer()
        let events = buffer.append("- [ ] pending\n\n")
        #expect(events == [
            .startList(ordered: false), .startTaskListItem(checkbox: .unchecked), .startParagraph, .text("pending"),
            .endParagraph, .endListItem, .endList,
        ])
    }

    @Test("Finalize closes open list")
    func finalizeList() {
        var buffer = StreamBuffer()
        _ = buffer.append("- item\n")
        let events = buffer.finalize()
        #expect(events == [.endParagraph, .endListItem, .endList])
    }

    // MARK: - Blockquote Detection

    @Test("Simple blockquote")
    func simpleBlockquote() {
        var buffer = StreamBuffer()
        let events = buffer.append("> text\n\n")
        #expect(events == [
            .startBlockQuote, .startParagraph, .text("text"),
            .endParagraph, .endBlockQuote,
        ])
    }

    @Test("Multi-line blockquote")
    func multiLineBlockquote() {
        var buffer = StreamBuffer()
        let events = buffer.append("> line one\n> line two\n\n")
        #expect(events == [
            .startBlockQuote, .startParagraph, .text("line one"),
            .text(" line two"),
            .endParagraph, .endBlockQuote,
        ])
    }

    @Test("Nested blockquote preserves depth transitions")
    func nestedBlockquote() {
        var buffer = StreamBuffer()
        let events = buffer.append("> outer\n>> inner\n\n")
        #expect(events == [
            .startBlockQuote, .startParagraph, .text("outer"),
            .endParagraph, .startBlockQuote, .startParagraph, .text("inner"),
            .endParagraph, .endBlockQuote, .endBlockQuote,
        ])
    }

    @Test("Nested blockquote list stays structural")
    func nestedBlockquoteList() {
        var buffer = StreamBuffer()
        let events = buffer.append("> outer\n>\n> > inner\n> >\n> > - first\n> > - second\n\n")
        #expect(events == [
            .startBlockQuote, .startParagraph, .text("outer"),
            .endParagraph,
            .startBlockQuote, .startParagraph, .text("inner"),
            .endParagraph,
            .startList(ordered: false), .startListItem, .startParagraph, .text("first"),
            .endParagraph, .endListItem, .startListItem, .startParagraph, .text("second"),
            .endParagraph, .endListItem, .endList, .endBlockQuote, .endBlockQuote,
        ])
    }

    @Test("Partial nested blockquote line does not preview raw markers")
    func partialNestedBlockquoteLine() {
        var buffer = StreamBuffer()
        _ = buffer.append("> outer\n>\n> > inner\n> >\n")

        let previewEvents = buffer.append("> > - fir")
        #expect(previewEvents.isEmpty)

        let completionEvents = buffer.append("st\n\n")
        #expect(completionEvents == [
            .startList(ordered: false), .startListItem, .startParagraph, .text("first"),
            .endParagraph, .endListItem, .endList, .endBlockQuote, .endBlockQuote,
        ])
    }

    @Test("List continuation preserves word separator in text events")
    func listContinuationSpacing() {
        var buffer = StreamBuffer()
        let events = buffer.append("- line one\nline two\n\n")
        #expect(events == [
            .startList(ordered: false), .startListItem, .startParagraph, .text("line one"),
            .text(" line two"),
            .endParagraph, .endListItem, .endList,
        ])
    }

    @Test("Finalize closes open blockquote")
    func finalizeBlockquote() {
        var buffer = StreamBuffer()
        _ = buffer.append("> quote\n")
        let events = buffer.finalize()
        #expect(events == [.endParagraph, .endBlockQuote])
    }

    // MARK: - Table Detection

    @Test("Table candidate confirmed by separator")
    func tableConfirmed() {
        var buffer = StreamBuffer()
        let events = buffer.append("| A | B |\n| - | - |\n| 1 | 2 |\n\n")
        #expect(events == [
            .startTable, .tableRow(["A", "B"]),
            .tableRow(["1", "2"]),
            .endTable,
        ])
    }

    @Test("Table candidate demoted to paragraph when no separator")
    func tableDemotedToParagraph() {
        var buffer = StreamBuffer()
        let events = buffer.append("| not a table |\nregular text\n\n")
        #expect(events.contains(.startParagraph))
        #expect(events.contains(.text("| not a table |")))
    }

    @Test("Finalize closes open table")
    func finalizeTable() {
        var buffer = StreamBuffer()
        _ = buffer.append("| A | B |\n| - | - |\n| 1 | 2 |\n")
        let events = buffer.finalize()
        #expect(events == [.endTable])
    }

    // MARK: - Adversarial Chunk Splits

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

    @Test("Adversarial: paragraph split across chunks")
    func adversarialParagraphSplit() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("He")
        #expect(events1 == [.startParagraph, .text("He")])

        let events2 = buffer.append("llo\n\n")
        #expect(events2 == [.text("llo"), .endParagraph])

        let events3 = buffer.append("World\n")
        #expect(events3 == [.startParagraph, .text("World")])
    }

    @Test("Partial list item waits for newline")
    func partialListItemWaitsForNewline() {
        var buffer = StreamBuffer()

        let events1 = buffer.append("- ite")
        #expect(events1.isEmpty)

        let events2 = buffer.append("m")
        #expect(events2.isEmpty)
    }

    @Test("Partial code line streams before newline inside fence")
    func partialCodeLineStreamsBeforeNewline() {
        var buffer = StreamBuffer()

        let events1 = buffer.append("```\npri")
        #expect(events1 == [.startCodeBlock(language: nil), .codeBlockText("pri")])

        let events2 = buffer.append("nt\n")
        #expect(events2 == [.codeBlockText("nt\n")])
    }

    @Test("Adversarial: heading split mid-prefix")
    func adversarialHeadingSplit() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("#")
        #expect(events1.isEmpty)

        let events2 = buffer.append("# Title\n")
        #expect(events2 == [.startHeading(level: 2), .text("Title"), .endHeading])
    }

    @Test("Adversarial: list marker split across chunks")
    func adversarialListSplit() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("-")
        #expect(events1.isEmpty)

        let events2 = buffer.append(" item\n\n")
        #expect(events2 == [
            .startList(ordered: false), .startListItem, .startParagraph, .text("item"),
            .endParagraph, .endListItem, .endList,
        ])
    }

    @Test("Adversarial: thematic break split")
    func adversarialThematicBreakSplit() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("--")
        #expect(events1.isEmpty)

        let events2 = buffer.append("-\n")
        #expect(events2 == [.thematicBreak])
    }

    @Test("Adversarial: ordered list marker split across chunks")
    func adversarialOrderedListSplit() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("1.")
        #expect(events1.isEmpty)

        let events2 = buffer.append(" item\n\n")
        #expect(events2 == [
            .startList(ordered: true), .startListItem, .startParagraph, .text("item"),
            .endParagraph, .endListItem, .endList,
        ])
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

    // MARK: - Mixed Content

    @Test("Heading followed by paragraph")
    func headingThenParagraph() {
        var buffer = StreamBuffer()
        let events = buffer.append("# Title\nSome text\n\n")
        #expect(events == [
            .startHeading(level: 1), .text("Title"), .endHeading,
            .startParagraph, .text("Some text"), .endParagraph,
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

    @Test("Finalize with no open block produces no events")
    func finalizeIdle() {
        var buffer = StreamBuffer()
        let events = buffer.finalize()
        #expect(events.isEmpty)
    }

    @Test("Finalize with partial line processes it first")
    func finalizePartialLine() {
        var buffer = StreamBuffer()
        _ = buffer.append("partial")
        let events = buffer.finalize()
        #expect(events.contains(.startParagraph))
        #expect(events.contains(.text("partial")))
        #expect(events.contains(.endParagraph))
    }
}
