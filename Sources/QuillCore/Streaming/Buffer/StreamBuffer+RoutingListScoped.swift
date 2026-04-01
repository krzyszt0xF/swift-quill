extension StreamBuffer {
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
            return closeOpenLists()
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
            var events = closeOpenLists()
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
            events.append(contentsOf: closeOpenLists())
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
