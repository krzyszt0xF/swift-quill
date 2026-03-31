struct StreamBuffer {
    private var state: State

    init(state: State = State()) {
        self.state = state
    }

    mutating func append(_ chunk: String) -> [ParserEvent] {
        guard !chunk.isEmpty else { return [] }

        var events: [ParserEvent] = []
        let combined = state.partialLine + chunk
        let segments = combined.split(separator: "\n", omittingEmptySubsequences: false)

        for index in 0..<(segments.count - 1) {
            events.append(contentsOf: processCompletedLine(String(segments[index])))
        }

        state.partialLine = String(segments.last ?? "")
        events.append(contentsOf: previewPartialLineIfNeeded())

        return events
    }

    mutating func finalize() -> [ParserEvent] {
        var events: [ParserEvent] = []

        if !state.partialLine.isEmpty {
            events.append(contentsOf: finalizePartialLine())
            state.partialLine = ""
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
        case codeBlockText(emittedText: String, indentToStrip: Int)
        case paragraph(emittedText: String, isContinuation: Bool)
    }

    enum BlockState: Equatable {
        case codeFence(marker: Character, count: Int, indentToStrip: Int)
        case heading
        case idle
        case paragraph
        case table
        case tableCandidate(headerLine: String)
    }

    struct State: Equatable {
        var blockquoteDepth = 0
        var blockState: BlockState = .idle
        var hasOpenListParagraph = false
        var partialLine = ""
        var listStack: [ListContext] = []
        var partialPreview: PartialPreview?
    }
}

// MARK: - Finalization

private extension StreamBuffer {
    mutating func closeCurrentBlock() -> [ParserEvent] {
        state.partialPreview = nil

        var events = closeOpenContent()
        events.append(contentsOf: StreamListTransitionPlanner.closeOpenLists(
            &state.listStack,
            hasOpenParagraph: &state.hasOpenListParagraph
        ))
        events.append(contentsOf: closeOpenBlockquotes())

        return events
    }

    mutating func closeOpenBlockquotes() -> [ParserEvent] {
        guard state.blockquoteDepth > 0 else { return [] }

        let events = Array(repeating: ParserEvent.endBlockQuote, count: state.blockquoteDepth)
        state.blockquoteDepth = 0

        return events
    }

    mutating func closeOpenContent() -> [ParserEvent] {
        let previousState = state.blockState
        state.blockState = .idle

        switch previousState {
        case .codeFence:
            return [.endCodeBlock]
        case .heading:
            return [.endHeading]
        case .idle:
            return []
        case .paragraph:
            state.hasOpenListParagraph = false
            return [.endParagraph]
        case .table:
            return [.endTable]
        case let .tableCandidate(headerLine):
            state.hasOpenListParagraph = false
            return [.startParagraph, .text(headerLine), .endParagraph]
        }
    }

    mutating func finalizePartialLine() -> [ParserEvent] {
        emitPreviewRemainder(for: state.partialLine) ?? processLine(state.partialLine)
    }
}

// MARK: - Partial Preview

private extension StreamBuffer {
    mutating func emitPreviewRemainder(for line: String) -> [ParserEvent]? {
        guard let partialPreview = state.partialPreview else { return nil }

        defer { state.partialPreview = nil }

        return PartialLinePreviewer.makeRemainderEvents(
            for: line,
            preview: partialPreview
        )
    }

    mutating func previewPartialLineIfNeeded() -> [ParserEvent] {
        guard state.partialLine.isEmpty == false else {
            state.partialPreview = nil
            return []
        }

        if StreamLineClassifier.parseBlockquotePrefix(state.partialLine) != nil {
            state.partialPreview = nil
            return []
        }

        if !state.listStack.isEmpty,
           StreamLineClassifier.isPotentialListMarkerPrefix(state.partialLine) {
            state.partialPreview = nil
            return []
        }

        guard let preview = PartialLinePreviewer.makePreview(
            for: state.partialLine,
            previousPreview: state.partialPreview,
            blockState: state.blockState
        ) else {
            state.partialPreview = nil
            return []
        }

        state.partialPreview = preview.preview
        state.blockState = preview.blockState
        if !state.listStack.isEmpty, case .paragraph = preview.blockState {
            state.hasOpenListParagraph = true
        }

        return preview.events
    }
}

// MARK: - Line Routing

private extension StreamBuffer {
    mutating func processCompletedLine(_ line: String) -> [ParserEvent] {
        emitPreviewRemainder(for: line) ?? processLine(line)
    }

    mutating func processContentLine(_ line: String) -> [ParserEvent] {
        if !state.listStack.isEmpty {
            return processListScopedLine(line)
        }

        switch state.blockState {
        case let .codeFence(marker, count, indentToStrip):
            return processCodeFenceLine(
                line,
                marker: marker,
                count: count,
                indentToStrip: indentToStrip
            )
        case .heading:
            return processHeadingLine(line)
        case .idle:
            return processIdleLine(line)
        case .paragraph:
            return processParagraphLine(line)
        case .table:
            return processTableLine(line)
        case let .tableCandidate(headerLine):
            return processTableCandidateLine(line, headerLine: headerLine)
        }
    }

    mutating func processHeadingLine(_: String) -> [ParserEvent] {
        state.blockState = .idle
        return [.endHeading]
    }

    mutating func processLine(_ line: String) -> [ParserEvent] {
        if let blockquotePrefix = StreamLineClassifier.parseBlockquotePrefix(line) {
            return processQuotedLine(
                blockquotePrefix.content,
                depth: blockquotePrefix.depth
            )
        }

        guard state.blockquoteDepth > 0 else {
            return processContentLine(line)
        }

        var events = closeOpenContent()
        events.append(contentsOf: StreamListTransitionPlanner.closeOpenLists(
            &state.listStack,
            hasOpenParagraph: &state.hasOpenListParagraph
        ))
        events.append(contentsOf: closeOpenBlockquotes())
        events.append(contentsOf: processContentLine(line))
        return events
    }
}

// MARK: - Blockquote

private extension StreamBuffer {
    mutating func processQuotedLine(
        _ line: String,
        depth: Int
    ) -> [ParserEvent] {
        var events = transitionBlockquoteDepth(to: depth)

        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            if case let .codeFence(marker, count, indentToStrip) = state.blockState {
                events.append(contentsOf: processCodeFenceLine(
                    "",
                    marker: marker,
                    count: count,
                    indentToStrip: indentToStrip
                ))
            } else {
                events.append(contentsOf: closeOpenContent())
                events.append(contentsOf: StreamListTransitionPlanner.closeOpenLists(
                    &state.listStack,
                    hasOpenParagraph: &state.hasOpenListParagraph
                ))
            }

            return events
        }

        events.append(contentsOf: processContentLine(line))
        return events
    }

    var shouldCloseOpenContentForBlockquoteDepthChange: Bool {
        switch state.blockState {
        case .codeFence, .idle:
            return false
        case .heading, .paragraph, .table, .tableCandidate:
            return true
        }
    }

    mutating func transitionBlockquoteDepth(to depth: Int) -> [ParserEvent] {
        guard depth != state.blockquoteDepth else { return [] }

        var events: [ParserEvent] = []
        if shouldCloseOpenContentForBlockquoteDepthChange {
            events.append(contentsOf: closeOpenContent())
            if depth < state.blockquoteDepth {
                events.append(contentsOf: StreamListTransitionPlanner.closeOpenLists(
                    &state.listStack,
                    hasOpenParagraph: &state.hasOpenListParagraph
                ))
            }
        }

        if depth < state.blockquoteDepth {
            events.append(contentsOf: Array(repeating: .endBlockQuote, count: state.blockquoteDepth - depth))
        } else {
            events.append(contentsOf: Array(repeating: .startBlockQuote, count: depth - state.blockquoteDepth))
        }

        state.blockquoteDepth = depth
        return events
    }
}

// MARK: - Root Content

private extension StreamBuffer {
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

// MARK: - List-Scoped Content

private extension StreamBuffer {
    mutating func makeListEmbeddedBlockEvents(
        for line: String,
        fromParagraph: Bool
    ) -> [ParserEvent]? {
        guard let currentList = state.listStack.last else { return nil }
        guard StreamLineClassifier.isListEmbeddedBlockCandidate(
            line,
            currentListIndent: currentList.indent
        ) else {
            return nil
        }

        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var events: [ParserEvent] = []

        if fromParagraph, state.hasOpenListParagraph {
            events.append(.endParagraph)
            state.hasOpenListParagraph = false
        }

        if let fence = StreamLineClassifier.parseFenceOpener(trimmed) {
            return makeCodeFenceStartEvents(
                language: fence.language,
                marker: fence.marker,
                count: fence.count,
                indentToStrip: StreamLineClassifier.leadingIndentWidth(in: line),
                precedingEvents: events
            )
        }

        if trimmed.contains("|") && trimmed.hasPrefix("|") {
            state.blockState = .tableCandidate(headerLine: trimmed)
            return events
        }

        if events.isEmpty == false {
            state.blockState = .idle
        }

        return events.isEmpty ? nil : events
    }

    mutating func processIdleListLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let currentList = state.listStack.last else {
            return processIdleLine(line)
        }

        if trimmed.isEmpty {
            state.blockState = .idle
            return StreamListTransitionPlanner.closeOpenLists(
                &state.listStack,
                hasOpenParagraph: &state.hasOpenListParagraph
            )
        }

        if let marker = StreamLineClassifier.parseListMarker(line) {
            let item = StreamLineClassifier.makeListItemContent(from: line, marker: marker)
            let events = StreamListTransitionPlanner.processListItemLine(
                item,
                marker: marker,
                listStack: &state.listStack,
                hasOpenParagraph: &state.hasOpenListParagraph
            )
            state.blockState = .paragraph
            return events
        }

        let staysInsideCurrentItem = StreamLineClassifier.isListEmbeddedBlockCandidate(
            line,
            currentListIndent: currentList.indent
        )
        if !staysInsideCurrentItem {
            state.blockState = .idle
            var events = StreamListTransitionPlanner.closeOpenLists(
                &state.listStack,
                hasOpenParagraph: &state.hasOpenListParagraph
            )
            events.append(contentsOf: processContentLine(line))
            return events
        }

        if let events = makeListEmbeddedBlockEvents(
            for: line,
            fromParagraph: false
        ) {
            return events
        }

        state.blockState = .paragraph
        state.hasOpenListParagraph = true
        return [.startParagraph, .text(trimmed)]
    }

    mutating func processListParagraphLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            state.blockState = .idle
            state.hasOpenListParagraph = false
            var events: [ParserEvent] = [.endParagraph]
            events.append(contentsOf: StreamListTransitionPlanner.closeOpenLists(
                &state.listStack,
                hasOpenParagraph: &state.hasOpenListParagraph
            ))
            return events
        }

        if let marker = StreamLineClassifier.parseListMarker(line) {
            let item = StreamLineClassifier.makeListItemContent(from: line, marker: marker)
            let events = StreamListTransitionPlanner.processListItemLine(
                item,
                marker: marker,
                listStack: &state.listStack,
                hasOpenParagraph: &state.hasOpenListParagraph
            )
            state.blockState = .paragraph
            return events
        }

        if let events = makeListEmbeddedBlockEvents(
            for: line,
            fromParagraph: true
        ) {
            return events
        }

        return [.text(StreamLineClassifier.makeContinuationText(from: trimmed))]
    }

    mutating func processListScopedLine(_ line: String) -> [ParserEvent] {
        switch state.blockState {
        case let .codeFence(marker, count, indentToStrip):
            return processCodeFenceLine(
                line,
                marker: marker,
                count: count,
                indentToStrip: indentToStrip
            )
        case .heading:
            return processHeadingLine(line)
        case .idle:
            return processIdleListLine(line)
        case .paragraph:
            return processListParagraphLine(line)
        case .table:
            return processListTableLine(line)
        case let .tableCandidate(headerLine):
            return processListTableCandidateLine(line, headerLine: headerLine)
        }
    }
}

// MARK: - Table and Fence Transitions

private extension StreamBuffer {
    mutating func makeCodeFenceStartEvents(
        language: String?,
        marker: Character,
        count: Int,
        indentToStrip: Int,
        precedingEvents: [ParserEvent] = []
    ) -> [ParserEvent] {
        state.blockState = .codeFence(
            marker: marker,
            count: count,
            indentToStrip: indentToStrip
        )

        return precedingEvents + [.startCodeBlock(language: language)]
    }

    mutating func makeTableStartEvents(
        headerLine: String,
        separatorLine: String
    ) -> [ParserEvent] {
        state.blockState = .table
        let alignments = StreamLineClassifier.parseTableAlignments(separatorLine)
        let cells = StreamLineClassifier.parseTableCells(headerLine)

        return [.startTable, .tableAlignments(alignments), .tableRow(cells)]
    }

    mutating func processListTableCandidateLine(
        _ line: String,
        headerLine: String
    ) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if StreamLineClassifier.isTableSeparator(trimmed) {
            return makeTableStartEvents(
                headerLine: headerLine,
                separatorLine: trimmed
            )
        }

        state.blockState = .paragraph
        state.hasOpenListParagraph = true
        var events: [ParserEvent] = [.startParagraph, .text(headerLine)]
        events.append(contentsOf: processListParagraphLine(line))
        return events
    }

    mutating func processListTableLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty || !trimmed.contains("|") {
            state.blockState = .idle
            var events: [ParserEvent] = [.endTable]
            if !trimmed.isEmpty {
                events.append(contentsOf: processIdleListLine(line))
            }
            return events
        }

        return [.tableRow(StreamLineClassifier.parseTableCells(trimmed))]
    }

    mutating func processTableCandidateLine(
        _ line: String,
        headerLine: String
    ) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if StreamLineClassifier.isTableSeparator(trimmed) {
            return makeTableStartEvents(
                headerLine: headerLine,
                separatorLine: trimmed
            )
        }

        state.blockState = .paragraph
        var events: [ParserEvent] = [.startParagraph, .text(headerLine)]
        events.append(contentsOf: processParagraphLine(line))
        return events
    }

    mutating func processTableLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty || !trimmed.contains("|") {
            state.blockState = .idle
            var events: [ParserEvent] = [.endTable]
            if !trimmed.isEmpty {
                events.append(contentsOf: processIdleLine(line))
            }
            return events
        }

        return [.tableRow(StreamLineClassifier.parseTableCells(trimmed))]
    }
}
