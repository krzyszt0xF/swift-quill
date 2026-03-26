enum StreamLineClassifier {
    struct BlockquotePrefix {
        let content: String
        let depth: Int
    }

    struct FenceInfo {
        let marker: Character
        let count: Int
        let language: String?
    }

    struct ListMarker {
        let indent: Int
        let ordered: Bool
        let length: Int
    }

    struct ListItemContent {
        let checkbox: Block.Checkbox?
        let content: String

        var startEvent: ParserEvent {
            if let checkbox {
                return .startTaskListItem(checkbox: checkbox)
            }
            return .startListItem
        }
    }

    static func extractBlockquoteContent(_ line: String) -> String {
        var content = String(line.dropFirst())
        if content.hasPrefix(" ") {
            content = String(content.dropFirst())
        }
        
        return content
    }

    static func parseBlockquotePrefix(_ line: String) -> BlockquotePrefix? {
        var index = line.startIndex
        var leadingSpaceCount = 0

        while index < line.endIndex && line[index] == " " && leadingSpaceCount < 3 {
            leadingSpaceCount += 1
            index = line.index(after: index)
        }

        guard index < line.endIndex, line[index] == ">" else {
            return nil
        }

        var depth = 0
        while index < line.endIndex && line[index] == ">" {
            depth += 1
            index = line.index(after: index)

            if index < line.endIndex && line[index] == " " {
                index = line.index(after: index)
            }
        }

        return BlockquotePrefix(
            content: String(line[index...]),
            depth: depth
        )
    }

    static func extractHeadingContent(_ line: String, level: Int) -> String {
        let prefixCount = level + 1
        
        return String(line.dropFirst(prefixCount)).trimmingCharacters(in: .whitespaces)
    }

    static func isClosingFence(_ line: String, marker: Character, minimumCount: Int) -> Bool {
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

    static func isTableSeparator(_ line: String) -> Bool {
        guard line.contains("|") && line.contains("-") else { return false }

        let stripped = line.replacingOccurrences(of: " ", with: "")
        let allowed: Set<Character> = ["|", "-", ":"]
        
        return stripped.allSatisfy { allowed.contains($0) }
    }

    static func isThematicBreak(_ line: String) -> Bool {
        let stripped = line.replacingOccurrences(of: " ", with: "")
        guard
            stripped.count >= 3,
            let first = stripped.first,
            first == "-" || first == "*" || first == "_"
        else { return false }

        return stripped.allSatisfy { $0 == first }
    }

    static func makeContinuationText(from text: String) -> String {
        guard !text.isEmpty else { return text }
        
        return " " + text
    }

    static func makeListItemContent(from line: String, marker: ListMarker) -> ListItemContent {
        let rawContent = String(line.dropFirst(marker.length))

        guard let checkbox = makeTaskListCheckbox(from: rawContent) else {
            return ListItemContent(checkbox: nil, content: rawContent)
        }

        return ListItemContent(
            checkbox: checkbox.checkbox,
            content: checkbox.content
        )
    }

    static func parseFenceOpener(_ line: String) -> FenceInfo? {
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
            return FenceInfo(marker: marker, count: count, language: language)
        } else {
            let rest = String(line[index...]).trimmingCharacters(in: .whitespaces)
            let language = rest.isEmpty ? nil : rest
            return FenceInfo(marker: marker, count: count, language: language)
        }
    }

    static func parseHeadingPrefix(_ line: String) -> Int? {
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

    static func parseListMarker(_ line: String) -> ListMarker? {
        let indent = line.prefix { $0 == " " || $0 == "\t" }.count
        let contentStart = line.index(line.startIndex, offsetBy: indent, limitedBy: line.endIndex) ?? line.endIndex
        let content = line[contentStart...]

        if content.hasPrefix("- ") { return ListMarker(indent: indent, ordered: false, length: indent + 2) }
        if content.hasPrefix("* ") { return ListMarker(indent: indent, ordered: false, length: indent + 2) }
        if content.hasPrefix("+ ") { return ListMarker(indent: indent, ordered: false, length: indent + 2) }

        var index = content.startIndex
        while index < content.endIndex && content[index].isNumber {
            index = content.index(after: index)
        }

        if index > content.startIndex && index < content.endIndex {
            let afterDigits = content[index]
            let nextIndex = content.index(after: index)
            if (afterDigits == "." || afterDigits == ")") && nextIndex < content.endIndex && content[nextIndex] == " " {
                let markerLength = content.distance(from: content.startIndex, to: nextIndex) + 1
                return ListMarker(indent: indent, ordered: true, length: indent + markerLength)
            }
        }

        return nil
    }

    static func parseTableCells(_ line: String) -> [String] {
        var cells = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        if cells.first?.isEmpty == true { cells.removeFirst() }
        if cells.last?.isEmpty == true { cells.removeLast() }

        return cells
    }
}

private extension StreamLineClassifier {
    static func makeTaskListCheckbox(from content: String) -> (checkbox: Block.Checkbox, content: String)? {
        if content.hasPrefix("[ ] ") {
            return (.unchecked, String(content.dropFirst(4)))
        }
        if content == "[ ]" {
            return (.unchecked, "")
        }
        if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
            return (.checked, String(content.dropFirst(4)))
        }
        if content == "[x]" || content == "[X]" {
            return (.checked, "")
        }

        return nil
    }
}
