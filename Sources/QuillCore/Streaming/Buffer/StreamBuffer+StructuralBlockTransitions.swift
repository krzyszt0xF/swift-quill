extension StreamBuffer {
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
