@testable import QuillCore
import QuillSharedTestSupport
import Testing

@Suite("StreamBuffer Paragraphs and Headings", .tags(.streaming))
struct StreamBufferParagraphAndHeadingTests {
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

    @Test("Injected state allows targeted finalize coverage")
    func finalizeInjectedState() {
        var buffer = StreamBuffer(state: .init(blockquoteDepth: 1, blockState: .paragraph))
        let events = buffer.finalize()
        #expect(events == [.endParagraph, .endBlockQuote])
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

    @Test("Partial heading streams incrementally before newline")
    func partialHeadingStreamsIncrementally() {
        var buffer = StreamBuffer()

        let partialEvents = buffer.append("## Tit")
        #expect(partialEvents == [.startHeading(level: 2), .text("Tit")])

        let completionEvents = buffer.append("le\n")
        #expect(completionEvents == [.text("le"), .endHeading])
    }

    @Test("Partial heading after paragraph closes paragraph before streaming heading")
    func partialHeadingAfterParagraphStreamsIncrementally() {
        var buffer = StreamBuffer()

        let partialEvents = buffer.append("Intro paragraph\n## Tit")
        #expect(partialEvents == [
            .startParagraph, .text("Intro paragraph"),
            .endParagraph, .startHeading(level: 2), .text("Tit"),
        ])

        let completionEvents = buffer.append("le\n")
        #expect(completionEvents == [.text("le"), .endHeading])
    }

    @Test("Seven hashes is not a heading")
    func sevenHashesNotHeading() {
        var buffer = StreamBuffer()
        let events = buffer.append("####### Not a heading\n\n")
        #expect(events.contains(.startParagraph))
    }

    @Test("Top-level numeric paragraph still previews as paragraph")
    func topLevelNumericParagraphPreview() {
        var buffer = StreamBuffer()

        let events = buffer.append("2026")
        #expect(events == [.startParagraph, .text("2026")])
    }

    @Test("Adversarial: heading split mid-prefix")
    func adversarialHeadingSplit() {
        var buffer = StreamBuffer()
        let events1 = buffer.append("#")
        #expect(events1.isEmpty)

        let events2 = buffer.append("# Title\n")
        #expect(events2 == [.startHeading(level: 2), .text("Title"), .endHeading])
    }

    @Test("Heading followed by paragraph")
    func headingThenParagraph() {
        var buffer = StreamBuffer()
        let events = buffer.append("# Title\nSome text\n\n")
        #expect(events == [
            .startHeading(level: 1), .text("Title"), .endHeading,
            .startParagraph, .text("Some text"), .endParagraph,
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
        let appendEvents = buffer.append("partial")
        let finalizeEvents = buffer.finalize()
        #expect(appendEvents == [.startParagraph, .text("partial")])
        #expect(finalizeEvents == [.endParagraph])
    }

    @Test("Finalize closes open partial heading without duplicating text")
    func finalizePartialHeading() {
        var buffer = StreamBuffer()

        let appendEvents = buffer.append("## Title")
        let finalizeEvents = buffer.finalize()

        #expect(appendEvents == [.startHeading(level: 2), .text("Title")])
        #expect(finalizeEvents == [.endHeading])
    }
}
