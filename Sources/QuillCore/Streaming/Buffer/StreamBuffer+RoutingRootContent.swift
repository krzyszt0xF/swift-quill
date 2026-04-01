extension StreamBuffer {
    mutating func processCodeFenceLine(
        _ line: String,
        marker: Character,
        count: Int,
        indentToStrip: Int
    ) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if StreamLineClassifier.isClosingFence(trimmed, marker: marker, minimumCount: count) {
            state.blockState = .idle
            return [.endCodeBlock]
        }

        let codeLine = line.removingLeadingIndent(width: indentToStrip)
        return [.codeBlockText(codeLine + "\n")]
    }

    mutating func processIdleLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return []
        }

        if let fence = StreamLineClassifier.parseFenceOpener(trimmed) {
            return makeCodeFenceStartEvents(
                language: fence.language,
                marker: fence.marker,
                count: fence.count,
                indentToStrip: 0
            )
        }

        if let level = StreamLineClassifier.parseHeadingPrefix(trimmed) {
            let content = StreamLineClassifier.extractHeadingContent(trimmed, level: level)
            state.blockState = .idle
            return [.startHeading(level: level), .text(content), .endHeading]
        }

        if StreamLineClassifier.isThematicBreak(trimmed) {
            return [.thematicBreak]
        }

        if let marker = StreamLineClassifier.parseListMarker(line) {
            let item = StreamLineClassifier.makeListItemContent(from: line, marker: marker)
            state.listStack = [ListContext(indent: marker.indent, ordered: marker.ordered)]
            state.hasOpenListParagraph = true
            state.blockState = .paragraph
            return [.startList(ordered: marker.ordered), item.startEvent, .startParagraph, .text(item.content)]
        }

        if trimmed.contains("|") && trimmed.hasPrefix("|") {
            state.blockState = .tableCandidate(headerLine: trimmed)
            return []
        }

        state.blockState = .paragraph
        return [.startParagraph, .text(trimmed)]
    }

    mutating func processParagraphLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            state.blockState = .idle
            return [.endParagraph]
        }

        if let fence = StreamLineClassifier.parseFenceOpener(trimmed) {
            return makeCodeFenceStartEvents(
                language: fence.language,
                marker: fence.marker,
                count: fence.count,
                indentToStrip: 0,
                precedingEvents: [.endParagraph]
            )
        }

        if let level = StreamLineClassifier.parseHeadingPrefix(trimmed) {
            let content = StreamLineClassifier.extractHeadingContent(trimmed, level: level)
            state.blockState = .idle
            return [.endParagraph, .startHeading(level: level), .text(content), .endHeading]
        }

        if StreamLineClassifier.isThematicBreak(trimmed) {
            state.blockState = .idle
            return [.endParagraph, .thematicBreak]
        }

        if let marker = StreamLineClassifier.parseListMarker(line) {
            let item = StreamLineClassifier.makeListItemContent(from: line, marker: marker)
            state.listStack = [ListContext(indent: marker.indent, ordered: marker.ordered)]
            state.hasOpenListParagraph = true
            state.blockState = .paragraph
            return [.endParagraph, .startList(ordered: marker.ordered), item.startEvent, .startParagraph, .text(item.content)]
        }

        return [.text(StreamLineClassifier.makeContinuationText(from: trimmed))]
    }
}
