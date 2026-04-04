extension StreamBuffer {
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
        events.append(contentsOf: closeOpenLists())
        events.append(contentsOf: closeOpenBlockquotes())
        events.append(contentsOf: processContentLine(line))
        return events
    }
}
