struct StreamBuffer {
    private var partialLine = ""
    private var pendingLines: [String] = []
    private var listStack: [ListContext] = []
    private var state: State = .idle

    enum State: Equatable {
        case blockquote
        case codeFence(marker: Character, count: Int)
        case heading
        case idle
        case list
        case paragraph
        case table
        case tableCandidate(headerLine: String)
    }

    struct ListContext: Equatable {
        let indent: Int
        let ordered: Bool
    }

    mutating func append(_ chunk: String) -> [ParserEvent] {
        guard !chunk.isEmpty else { return [] }

        var events: [ParserEvent] = []
        let combined = partialLine + chunk
        let segments = combined.split(separator: "\n", omittingEmptySubsequences: false)

        for i in 0..<(segments.count - 1) {
            let line = String(segments[i])
            events.append(contentsOf: processLine(line))
        }

        partialLine = String(segments.last ?? "")
        return events
    }

    mutating func finalize() -> [ParserEvent] {
        var events: [ParserEvent] = []

        if !partialLine.isEmpty {
            events.append(contentsOf: processLine(partialLine))
            partialLine = ""
        }

        events.append(contentsOf: closeCurrentBlock())
        return events
    }
}

// MARK: - State Machine

private extension StreamBuffer {
    mutating func processLine(_ line: String) -> [ParserEvent] {
        switch state {
        case .blockquote:
            return processBlockquoteLine(line)
        case let .codeFence(marker, count):
            return processCodeFenceLine(line, marker: marker, count: count)
        case .heading:
            return processHeadingLine(line)
        case .idle:
            return processIdleLine(line)
        case .list:
            return processListLine(line)
        case .paragraph:
            return processParagraphLine(line)
        case .table:
            return processTableLine(line)
        case let .tableCandidate(headerLine):
            return processTableCandidateLine(line, headerLine: headerLine)
        }
    }

    mutating func processIdleLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return []
        }

        if let fence = StreamLineClassifier.parseFenceOpener(trimmed) {
            state = .codeFence(marker: fence.marker, count: fence.count)
            return [.startCodeBlock(language: fence.language)]
        }

        if let level = StreamLineClassifier.parseHeadingPrefix(trimmed) {
            let content = StreamLineClassifier.extractHeadingContent(trimmed, level: level)
            state = .idle
            return [.startHeading(level: level), .text(content), .endHeading]
        }

        if StreamLineClassifier.isThematicBreak(trimmed) {
            return [.thematicBreak]
        }

        if let marker = StreamLineClassifier.parseListMarker(line) {
            let item = StreamLineClassifier.makeListItemContent(from: line, marker: marker)
            state = .list
            listStack = [ListContext(indent: marker.indent, ordered: marker.ordered)]
            return [.startList(ordered: marker.ordered), item.startEvent, .startParagraph, .text(item.content)]
        }

        if trimmed.hasPrefix(">") {
            let content = StreamLineClassifier.extractBlockquoteContent(trimmed)
            state = .blockquote
            return [.startBlockQuote, .startParagraph, .text(content)]
        }

        if trimmed.contains("|") && trimmed.hasPrefix("|") {
            state = .tableCandidate(headerLine: trimmed)
            return []
        }

        state = .paragraph
        return [.startParagraph, .text(trimmed)]
    }

    mutating func processParagraphLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            state = .idle
            return [.endParagraph]
        }

        if let fence = StreamLineClassifier.parseFenceOpener(trimmed) {
            state = .codeFence(marker: fence.marker, count: fence.count)
            return [.endParagraph, .startCodeBlock(language: fence.language)]
        }

        if let level = StreamLineClassifier.parseHeadingPrefix(trimmed) {
            let content = StreamLineClassifier.extractHeadingContent(trimmed, level: level)
            state = .idle
            return [.endParagraph, .startHeading(level: level), .text(content), .endHeading]
        }

        if StreamLineClassifier.isThematicBreak(trimmed) {
            state = .idle
            return [.endParagraph, .thematicBreak]
        }

        if let marker = StreamLineClassifier.parseListMarker(line) {
            let item = StreamLineClassifier.makeListItemContent(from: line, marker: marker)
            state = .list
            listStack = [ListContext(indent: marker.indent, ordered: marker.ordered)]
            return [.endParagraph, .startList(ordered: marker.ordered), item.startEvent, .startParagraph, .text(item.content)]
        }

        if trimmed.hasPrefix(">") {
            let content = StreamLineClassifier.extractBlockquoteContent(trimmed)
            state = .blockquote
            return [.endParagraph, .startBlockQuote, .startParagraph, .text(content)]
        }

        return [.text(StreamLineClassifier.makeContinuationText(from: trimmed))]
    }

    mutating func processCodeFenceLine(
        _ line: String,
        marker: Character,
        count: Int
    ) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if StreamLineClassifier.isClosingFence(trimmed, marker: marker, minimumCount: count) {
            state = .idle
            return [.endCodeBlock]
        }

        return [.codeBlockText(line + "\n")]
    }

    mutating func processHeadingLine(_ line: String) -> [ParserEvent] {
        state = .idle
        return [.endHeading]
    }

    mutating func processListLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            state = .idle
            return ListParsingHelpers.closeOpenLists(&listStack)
        }

        if let marker = StreamLineClassifier.parseListMarker(line) {
            let item = StreamLineClassifier.makeListItemContent(from: line, marker: marker)
            return ListParsingHelpers.processListItemLine(item, marker: marker, listStack: &listStack)
        }

        return [.text(StreamLineClassifier.makeContinuationText(from: trimmed))]
    }

    mutating func processBlockquoteLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            state = .idle
            return [.endParagraph, .endBlockQuote]
        }

        if trimmed.hasPrefix(">") {
            let content = StreamLineClassifier.extractBlockquoteContent(trimmed)
            return [.text(StreamLineClassifier.makeContinuationText(from: content))]
        }

        state = .idle
        return [.endParagraph, .endBlockQuote]
    }

    mutating func processTableCandidateLine(
        _ line: String,
        headerLine: String
    ) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if StreamLineClassifier.isTableSeparator(trimmed) {
            state = .table
            let cells = StreamLineClassifier.parseTableCells(headerLine)
            return [.startTable, .tableRow(cells)]
        }

        state = .paragraph
        var events: [ParserEvent] = [.startParagraph, .text(headerLine)]
        events.append(contentsOf: processParagraphLine(line))
        return events
    }

    mutating func processTableLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty || !trimmed.contains("|") {
            state = .idle
            var events: [ParserEvent] = [.endTable]
            if !trimmed.isEmpty {
                events.append(contentsOf: processIdleLine(line))
            }
            return events
        }

        let cells = StreamLineClassifier.parseTableCells(trimmed)
        return [.tableRow(cells)]
    }

    mutating func closeCurrentBlock() -> [ParserEvent] {
        let previousState = state
        state = .idle

        switch previousState {
        case .blockquote:
            return [.endParagraph, .endBlockQuote]
        case .codeFence:
            return [.endCodeBlock]
        case .heading:
            return [.endHeading]
        case .idle:
            return []
        case .list:
            return ListParsingHelpers.closeOpenLists(&listStack)
        case .paragraph:
            return [.endParagraph]
        case .table:
            return [.endTable]
        case let .tableCandidate(headerLine):
            return [.startParagraph, .text(headerLine), .endParagraph]
        }
    }
}
