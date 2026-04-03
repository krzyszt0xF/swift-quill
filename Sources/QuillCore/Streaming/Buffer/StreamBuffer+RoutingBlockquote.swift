extension StreamBuffer {
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
                events.append(contentsOf: closeOpenLists())
            }

            return events
        }

        events.append(contentsOf: processContentLine(line))
        return events
    }

    var shouldCloseContentForDepthChange: Bool {
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
        if shouldCloseContentForDepthChange {
            events.append(contentsOf: closeOpenContent())
            if depth < state.blockquoteDepth {
                events.append(contentsOf: closeOpenLists())
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
