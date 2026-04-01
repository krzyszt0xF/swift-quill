struct StreamBuffer {
    var state: State

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
        case tableRow(emittedLine: String)
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
