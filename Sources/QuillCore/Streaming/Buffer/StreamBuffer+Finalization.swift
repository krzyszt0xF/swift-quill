extension StreamBuffer {
    mutating func closeCurrentBlock() -> [ParserEvent] {
        state.partialPreview = nil

        var events = closeOpenContent()
        events.append(contentsOf: closeOpenLists())
        events.append(contentsOf: closeOpenBlockquotes())

        return events
    }

    mutating func closeOpenLists() -> [ParserEvent] {
        StreamListTransitionPlanner.closeOpenLists(
            &state.listStack,
            hasOpenParagraph: &state.hasOpenListParagraph
        )
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
