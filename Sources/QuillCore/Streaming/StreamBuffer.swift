struct StreamBuffer {
    private var blockquoteDepth = 0
    private var partialLine = ""
    private var listStack: [ListContext] = []
    private var partialPreview: PartialPreview?
    private var state: State = .idle

    mutating func append(_ chunk: String) -> [ParserEvent] {
        guard !chunk.isEmpty else { return [] }

        var events: [ParserEvent] = []
        let combined = partialLine + chunk
        let segments = combined.split(separator: "\n", omittingEmptySubsequences: false)

        for index in 0..<(segments.count - 1) {
            let line = String(segments[index])
            events.append(contentsOf: processCompletedLine(line))
        }

        partialLine = String(segments.last ?? "")
        events.append(contentsOf: previewPartialLineIfNeeded())

        return events
    }

    mutating func finalize() -> [ParserEvent] {
        var events: [ParserEvent] = []

        if !partialLine.isEmpty {
            events.append(contentsOf: finalizePartialLine())
            partialLine = ""
        }

        events.append(contentsOf: closeCurrentBlock())

        return events
    }
}

extension StreamBuffer {
    struct ListContext: Equatable {
        let indent: Int
        let ordered: Bool
    }

    enum PartialPreview: Equatable {
        case codeBlockText(emittedText: String)
        case paragraph(emittedText: String, isContinuation: Bool)
    }

    enum State: Equatable {
        case codeFence(marker: Character, count: Int)
        case heading
        case idle
        case list
        case paragraph
        case table
        case tableCandidate(headerLine: String)
    }
}

// MARK: - State Machine

private extension StreamBuffer {
    mutating func closeCurrentBlock() -> [ParserEvent] {
        partialPreview = nil
        var events = closeOpenContent()
        events.append(contentsOf: closeOpenBlockquotes())
        return events
    }

    mutating func closeOpenBlockquotes() -> [ParserEvent] {
        guard blockquoteDepth > 0 else { return [] }

        let events = Array(repeating: ParserEvent.endBlockQuote, count: blockquoteDepth)
        blockquoteDepth = 0
        return events
    }

    mutating func closeOpenContent() -> [ParserEvent] {
        let previousState = state
        state = .idle

        switch previousState {
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

    mutating func emitPreviewRemainder(for line: String) -> [ParserEvent]? {
        guard let partialPreview else { return nil }

        defer { self.partialPreview = nil }

        return PartialLinePreviewer.makeRemainderEvents(for: line, preview: partialPreview)
    }

    mutating func finalizePartialLine() -> [ParserEvent] {
        emitPreviewRemainder(for: partialLine) ?? processLine(partialLine)
    }

    mutating func previewPartialLineIfNeeded() -> [ParserEvent] {
        guard partialLine.isEmpty == false else {
            partialPreview = nil
            return []
        }

        if StreamLineClassifier.parseBlockquotePrefix(partialLine) != nil {
            partialPreview = nil
            return []
        }

        guard let preview = PartialLinePreviewer.makePreview(
            for: partialLine,
            previousPreview: partialPreview,
            state: state
        ) else {
            partialPreview = nil
            return []
        }

        partialPreview = preview.preview
        state = preview.state
        return preview.events
    }

    mutating func processCompletedLine(_ line: String) -> [ParserEvent] {
        emitPreviewRemainder(for: line) ?? processLine(line)
    }

    mutating func processLine(_ line: String) -> [ParserEvent] {
        if let blockquotePrefix = StreamLineClassifier.parseBlockquotePrefix(line) {
            return processQuotedLine(
                blockquotePrefix.content,
                depth: blockquotePrefix.depth
            )
        }

        guard blockquoteDepth > 0 else {
            return processContentLine(line)
        }

        var events = closeOpenContent()
        events.append(contentsOf: closeOpenBlockquotes())
        events.append(contentsOf: processContentLine(line))
        return events
    }

    mutating func processContentLine(_ line: String) -> [ParserEvent] {
        switch state {
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

    mutating func processQuotedLine(
        _ line: String,
        depth: Int
    ) -> [ParserEvent] {
        var events = transitionBlockquoteDepth(to: depth)

        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            if case let .codeFence(marker, count) = state {
                events.append(contentsOf: processCodeFenceLine("", marker: marker, count: count))
            } else {
                events.append(contentsOf: closeOpenContent())
            }
            return events
        }

        events.append(contentsOf: processContentLine(line))
        return events
    }

    mutating func transitionBlockquoteDepth(to depth: Int) -> [ParserEvent] {
        guard depth != blockquoteDepth else { return [] }

        var events: [ParserEvent] = []
        if shouldCloseOpenContentForBlockquoteDepthChange {
            events.append(contentsOf: closeOpenContent())
        }

        if depth < blockquoteDepth {
            events.append(contentsOf: Array(repeating: .endBlockQuote, count: blockquoteDepth - depth))
        } else {
            events.append(contentsOf: Array(repeating: .startBlockQuote, count: depth - blockquoteDepth))
        }

        blockquoteDepth = depth
        return events
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

    var shouldCloseOpenContentForBlockquoteDepthChange: Bool {
        switch state {
        case .codeFence, .idle:
            return false
        case .heading, .list, .paragraph, .table, .tableCandidate:
            return true
        }
    }
}
