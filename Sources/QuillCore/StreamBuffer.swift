struct StreamBuffer {
    private var partialLine = ""
    private var pendingLines: [String] = []
    private var state: State = .idle

    enum State: Equatable {
        case blockquote
        case codeFence(marker: Character, count: Int)
        case heading
        case idle
        case list(ordered: Bool)
        case paragraph
        case table
        case tableCandidate(headerLine: String)
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

    // MARK: - State Handling

    mutating func processIdleLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            return []
        }

        if let fence = parseFenceOpener(trimmed) {
            state = .codeFence(marker: fence.marker, count: fence.count)
            return [.startCodeBlock(language: fence.language)]
        }

        if let level = parseHeadingPrefix(trimmed) {
            let content = extractHeadingContent(trimmed, level: level)
            state = .idle
            return [.startHeading(level: level), .text(content), .endHeading]
        }

        if isThematicBreak(trimmed) {
            return [.thematicBreak]
        }

        if let marker = parseListMarker(trimmed) {
            let content = extractListItemContent(trimmed, marker: marker)
            state = .list(ordered: marker.ordered)
            return [.startList(ordered: marker.ordered), .startListItem, .text(content)]
        }

        if trimmed.hasPrefix(">") {
            let content = extractBlockquoteContent(trimmed)
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

        if let fence = parseFenceOpener(trimmed) {
            state = .codeFence(marker: fence.marker, count: fence.count)
            return [.endParagraph, .startCodeBlock(language: fence.language)]
        }

        if let level = parseHeadingPrefix(trimmed) {
            let content = extractHeadingContent(trimmed, level: level)
            state = .idle
            return [.endParagraph, .startHeading(level: level), .text(content), .endHeading]
        }

        if isThematicBreak(trimmed) {
            state = .idle
            return [.endParagraph, .thematicBreak]
        }

        if let marker = parseListMarker(trimmed) {
            let content = extractListItemContent(trimmed, marker: marker)
            state = .list(ordered: marker.ordered)
            return [.endParagraph, .startList(ordered: marker.ordered), .startListItem, .text(content)]
        }

        if trimmed.hasPrefix(">") {
            let content = extractBlockquoteContent(trimmed)
            state = .blockquote
            return [.endParagraph, .startBlockQuote, .startParagraph, .text(content)]
        }

        return [.text(trimmed)]
    }

    mutating func processCodeFenceLine(
        _ line: String,
        marker: Character,
        count: Int
    ) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if isClosingFence(trimmed, marker: marker, minimumCount: count) {
            state = .idle
            return [.endCodeBlock]
        }

        return [.codeBlockText(line)]
    }

    mutating func processHeadingLine(_ line: String) -> [ParserEvent] {
        state = .idle
        return [.endHeading]
    }

    mutating func processListLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            state = .idle
            return [.endListItem, .endList]
        }

        if let marker = parseListMarker(trimmed) {
            let content = extractListItemContent(trimmed, marker: marker)
            return [.endListItem, .startListItem, .text(content)]
        }

        return [.text(trimmed)]
    }

    mutating func processBlockquoteLine(_ line: String) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            state = .idle
            return [.endParagraph, .endBlockQuote]
        }

        if trimmed.hasPrefix(">") {
            let content = extractBlockquoteContent(trimmed)
            return [.text(content)]
        }

        state = .idle
        return [.endParagraph, .endBlockQuote]
    }

    mutating func processTableCandidateLine(
        _ line: String,
        headerLine: String
    ) -> [ParserEvent] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if isTableSeparator(trimmed) {
            state = .table
            let cells = parseTableCells(headerLine)
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

        let cells = parseTableCells(trimmed)
        return [.tableRow(cells)]
    }

    // MARK: - Close Current Block

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
            return [.endListItem, .endList]
        case .paragraph:
            return [.endParagraph]
        case .table:
            return [.endTable]
        case let .tableCandidate(headerLine):
            return [.startParagraph, .text(headerLine), .endParagraph]
        }
    }

    // MARK: - Line Detection Helpers

    func parseFenceOpener(_ line: String) -> (marker: Character, count: Int, language: String?)? {
        guard let first = line.first, first == "`" || first == "~" else { return nil }

        let marker = first
        var count = 0
        var index = line.startIndex

        while index < line.endIndex && line[index] == marker {
            count += 1
            index = line.index(after: index)
        }

        guard count >= 3 else { return nil }

        if marker == "`" {
            let rest = String(line[index...]).trimmingCharacters(in: .whitespaces)
            if rest.contains("`") { return nil }
            let language = rest.isEmpty ? nil : rest
            return (marker, count, language)
        } else {
            let rest = String(line[index...]).trimmingCharacters(in: .whitespaces)
            let language = rest.isEmpty ? nil : rest
            return (marker, count, language)
        }
    }

    func isClosingFence(_ line: String, marker: Character, minimumCount: Int) -> Bool {
        guard let first = line.first, first == marker else { return false }

        var count = 0
        for ch in line {
            if ch == marker {
                count += 1
            } else if ch == " " || ch == "\t" {
                continue
            } else {
                return false
            }
        }

        return count >= minimumCount
    }

    func parseHeadingPrefix(_ line: String) -> Int? {
        var level = 0
        var index = line.startIndex

        while index < line.endIndex && line[index] == "#" {
            level += 1
            index = line.index(after: index)
        }

        guard
            level >= 1 && level <= 6,
            index < line.endIndex && line[index] == " "
        else { return nil }

        return level
    }

    func extractHeadingContent(_ line: String, level: Int) -> String {
        let prefixCount = level + 1
        return String(line.dropFirst(prefixCount)).trimmingCharacters(in: .whitespaces)
    }

    func isThematicBreak(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard
            stripped.count >= 3,
            let first = stripped.first,
            first == "-" || first == "*" || first == "_"
        else { return false }
        
        return stripped.allSatisfy { $0 == first }
    }

    struct ListMarker {
        let ordered: Bool
        let length: Int
    }

    func parseListMarker(_ line: String) -> ListMarker? {
        if line.hasPrefix("- ") { return ListMarker(ordered: false, length: 2) }
        if line.hasPrefix("* ") { return ListMarker(ordered: false, length: 2) }
        if line.hasPrefix("+ ") { return ListMarker(ordered: false, length: 2) }

        var index = line.startIndex
        while index < line.endIndex && line[index].isNumber {
            index = line.index(after: index)
        }

        if index > line.startIndex && index < line.endIndex {
            let afterDigits = line[index]
            let nextIndex = line.index(after: index)
            if (afterDigits == "." || afterDigits == ")") && nextIndex < line.endIndex && line[nextIndex] == " " {
                let markerLen = line.distance(from: line.startIndex, to: nextIndex) + 1
                return ListMarker(ordered: true, length: markerLen)
            }
        }

        return nil
    }

    func extractListItemContent(_ line: String, marker: ListMarker) -> String {
        String(line.dropFirst(marker.length))
    }

    func extractBlockquoteContent(_ line: String) -> String {
        var content = String(line.dropFirst())
        if content.hasPrefix(" ") {
            content = String(content.dropFirst())
        }
        return content
    }

    func isTableSeparator(_ line: String) -> Bool {
        guard line.contains("|") && line.contains("-") else { return false }
        
        let stripped = line.replacingOccurrences(of: " ", with: "")
        let allowed: Set<Character> = ["|", "-", ":"]
        return stripped.allSatisfy { allowed.contains($0) }
    }

    func parseTableCells(_ line: String) -> [String] {
        var cells = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }

        return cells
    }
}
