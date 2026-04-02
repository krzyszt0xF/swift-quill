@testable import QuillCore
import QuillSharedTestSupport
import Testing

@Suite("StreamBuffer Lists, Blockquotes, and Tables", .tags(.streaming))
struct StreamBufferListBlockquoteAndTableTests {
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

    @Test("Nested fenced code block inside list item emits code block events")
    func nestedFencedCodeBlockInListItem() {
        var buffer = StreamBuffer()
        let events = buffer.append("""
        1. Outer
           - Code
             ```python
             print("Hello")
             ```

        """)

        #expect(events == [
            .startList(ordered: true), .startListItem, .startParagraph, .text("Outer"),
            .endParagraph, .startList(ordered: false), .startListItem, .startParagraph, .text("Code"),
            .endParagraph,
            .startCodeBlock(language: "python"),
            .codeBlockText("print(\"Hello\")\n"),
            .endCodeBlock,
        ])

        let finalEvents = buffer.finalize()
        #expect(finalEvents == [.endListItem, .endList, .endListItem, .endList])
    }

    @Test("Nested table inside list item stays in list-scoped routing")
    func nestedTableInListItem() {
        var buffer = StreamBuffer()
        let events = buffer.append("""
        - Outer
          | A | B |
          | - | - |
          | 1 | 2 |
        """)

        #expect(events == [
            .startList(ordered: false), .startListItem, .startParagraph, .text("Outer"),
            .endParagraph,
            .startTable, .tableAlignments([nil, nil]), .tableRow(["A", "B"]),
            .tableRow(["1", "2"]),
        ])

        let finalEvents = buffer.finalize()
        #expect(finalEvents == [.endTable, .endListItem, .endList])
    }

    @Test("Blank line closes list before dedented top-level paragraph")
    func blankLineClosesListBeforeTopLevelParagraph() {
        var buffer = StreamBuffer()
        let events = buffer.append("""
        - item

        After
        """)

        #expect(events == [
            .startList(ordered: false), .startListItem, .startParagraph, .text("item"),
            .endParagraph, .endListItem, .endList,
            .startParagraph, .text("After"),
        ])
    }

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

    @Test("Prompt nested ordered list emits nested ordered events")
    func promptNestedOrderedList() {
        var buffer = StreamBuffer()
        let events = buffer.append("""
        1. Parse markdown into a stable block tree
           1. Preserve nested ordered numbering
           2. Keep wrapped lines aligned under the marker when they span more than one visual row in the narrow stream pane

        """)

        #expect(events == [
            .startList(ordered: true), .startListItem, .startParagraph, .text("Parse markdown into a stable block tree"),
            .endParagraph, .startList(ordered: true), .startListItem, .startParagraph, .text("Preserve nested ordered numbering"),
            .endParagraph, .endListItem, .startListItem, .startParagraph, .text("Keep wrapped lines aligned under the marker when they span more than one visual row in the narrow stream pane"),
        ])

        let finalEvents = buffer.finalize()
        #expect(finalEvents == [.endParagraph, .endListItem, .endList, .endListItem, .endList])
    }

    @Test("Finalize closes open blockquote")
    func finalizeBlockquote() {
        var buffer = StreamBuffer()
        _ = buffer.append("> quote\n")
        let events = buffer.finalize()
        #expect(events == [.endParagraph, .endBlockQuote])
    }

    @Test("Table candidate confirmed by separator")
    func tableConfirmed() {
        var buffer = StreamBuffer()
        let events = buffer.append("| A | B |\n| - | - |\n| 1 | 2 |\n\n")
        #expect(events == [
            .startTable, .tableAlignments([nil, nil]), .tableRow(["A", "B"]),
            .tableRow(["1", "2"]),
            .endTable,
        ])
    }

    @Test("Table separator with mixed alignments emits alignment event")
    func tableMixedAlignments() {
        var buffer = StreamBuffer()
        let events = buffer.append("| A | B | C |\n| :--- | :---: | ---: |\n| 1 | 2 | 3 |\n\n")
        #expect(events == [
            .startTable,
            .tableAlignments([.left, .center, .right]),
            .tableRow(["A", "B", "C"]),
            .tableRow(["1", "2", "3"]),
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

    @Test("Partial next task list item does not leak into current paragraph preview")
    func partialNextTaskListItemDoesNotLeakIntoCurrentParagraphPreview() {
        var buffer = StreamBuffer()

        let events1 = buffer.append("- [x] first\n- [x] se")
        #expect(events1 == [
            .startList(ordered: false), .startTaskListItem(checkbox: .checked), .startParagraph, .text("first"),
        ])

        let events2 = buffer.append("cond\n\n")
        #expect(events2 == [
            .endParagraph, .endListItem,
            .startTaskListItem(checkbox: .checked), .startParagraph, .text("second"),
            .endParagraph, .endListItem, .endList,
        ])
    }

    @Test("Partial nested ordered item does not leak into parent paragraph preview")
    func partialNestedOrderedItemDoesNotLeakIntoParentParagraphPreview() {
        var buffer = StreamBuffer()

        let events1 = buffer.append("1. Parse markdown into a stable block tree\n   1")
        #expect(events1 == [
            .startList(ordered: true), .startListItem, .startParagraph, .text("Parse markdown into a stable block tree"),
        ])

        let events2 = buffer.append(". Preserve nested ordered numbering\n")
        #expect(events2 == [
            .endParagraph, .startList(ordered: true), .startListItem, .startParagraph, .text("Preserve nested ordered numbering"),
        ])
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
}
