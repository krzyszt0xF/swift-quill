package enum InlineParser {
    package static func parse(_ text: String) -> [Inline] {
        var parser = Parser(source: text[...])
        return parser.makeParsedInlines()
    }
}

private extension InlineParser {
    enum Delimiter {
        case emphasis
        case strikethrough
        case strong

        var token: String {
            switch self {
            case .emphasis:
                "*"
            case .strikethrough:
                "~~"
            case .strong:
                "**"
            }
        }
    }

    struct ParseResult {
        let didReachDelimiter: Bool
        let inlines: [Inline]
    }

    struct Parser {
        let source: Substring
        var position: Substring.Index

        init(source: Substring) {
            self.source = source
            position = source.startIndex
        }
    }
}

private extension InlineParser.Parser {
    mutating func makeParsedInlines() -> [Inline] {
        makeCoalescedInlines(from: parse(until: nil).inlines)
    }

    mutating func parse(until delimiter: InlineParser.Delimiter?) -> InlineParser.ParseResult {
        var inlines: [Inline] = []
        var textBuffer = ""

        while position < source.endIndex {
            if let delimiter,
               checkClosingDelimiter(delimiter) {
                appendText(textBuffer, to: &inlines)
                advance(by: delimiter.token)
                return InlineParser.ParseResult(
                    didReachDelimiter: true,
                    inlines: inlines
                )
            }

            if checkTokenPrefix("![") {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: parseImageInlines())
                continue
            }

            if checkTokenPrefix("**") {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: parseStrongInlines())
                continue
            }

            if checkTokenPrefix("~~") {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: parseStrikethroughInlines())
                continue
            }

            if checkTokenPrefix("`") {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(parseBacktickInline())
                continue
            }

            if checkTokenPrefix("[") {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: parseLinkInlines())
                continue
            }

            if checkTokenPrefix("*"),
               checkCanStartEmphasis() {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: parseEmphasisInlines())
                continue
            }

            textBuffer.append(source[position])
            advance()
        }

        appendText(textBuffer, to: &inlines)
        return InlineParser.ParseResult(
            didReachDelimiter: false,
            inlines: inlines
        )
    }
}

private extension InlineParser.Parser {
    mutating func advance() {
        position = source.index(after: position)
    }

    mutating func advance(by token: String) {
        for _ in token {
            guard position < source.endIndex else { return }
            advance()
        }
    }

    mutating func advancePastIncompleteDestination() {
        while position < source.endIndex {
            guard !checkWhitespace(source[position]) else { return }
            advance()
        }
    }

    func checkCanStartEmphasis() -> Bool {
        let nextPosition = source.index(after: position)
        guard nextPosition < source.endIndex else { return false }
        return !checkWhitespace(source[nextPosition])
    }

    func checkClosingDelimiter(_ delimiter: InlineParser.Delimiter) -> Bool {
        switch delimiter {
        case .emphasis:
            return checkTokenPrefix("*") && !checkTokenPrefix("**")
        case .strikethrough, .strong:
            return checkTokenPrefix(delimiter.token)
        }
    }

    func checkTokenPrefix(_ token: String) -> Bool {
        source[position...].hasPrefix(token)
    }

    func checkWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(\.properties.isWhitespace)
    }

    func findClosingBracket(startingAt start: Substring.Index) -> Substring.Index? {
        var bracketDepth = 0
        var searchIndex = start

        while searchIndex < source.endIndex {
            switch source[searchIndex] {
            case "[":
                bracketDepth += 1
            case "]":
                guard bracketDepth > 0 else { return searchIndex }
                bracketDepth -= 1
            default:
                break
            }
            searchIndex = source.index(after: searchIndex)
        }

        return nil
    }

    func findClosingParenthesis(startingAt start: Substring.Index) -> Substring.Index? {
        var searchIndex = start

        while searchIndex < source.endIndex {
            guard source[searchIndex] != ")" else { return searchIndex }
            searchIndex = source.index(after: searchIndex)
        }

        return nil
    }

    func makeCoalescedInlines(from inlines: [Inline]) -> [Inline] {
        var result: [Inline] = []

        for inline in inlines {
            if case let .text(text) = inline,
               case let .text(previousText)? = result.last {
                result[result.count - 1] = .text(previousText + text)
                continue
            }

            result.append(inline)
        }

        return result
    }

    func makeLabelInlines(in range: Range<Substring.Index>) -> [Inline] {
        InlineParser.parse(String(source[range]))
    }

    func makeMalformedLabelInlines(from start: Substring.Index) -> [Inline] {
        InlineParser.parse(String(source[start...]))
    }

    mutating func parseBacktickInline() -> Inline {
        advance()

        guard let closingIndex = source[position...].firstIndex(of: "`") else {
            let code = String(source[position...])
            position = source.endIndex
            return .code(code)
        }

        let code = String(source[position..<closingIndex])
        position = source.index(after: closingIndex)
        return .code(code)
    }

    mutating func parseDelimitedInlines(
        delimiter: InlineParser.Delimiter,
        makeInline: ([Inline]) -> Inline
    ) -> [Inline] {
        advance(by: delimiter.token)
        let result = parse(until: delimiter)

        guard result.didReachDelimiter else {
            return result.inlines
        }

        return [makeInline(result.inlines)]
    }

    mutating func parseEmphasisInlines() -> [Inline] {
        parseDelimitedInlines(delimiter: .emphasis) { .emphasis($0) }
    }

    mutating func parseImageInlines() -> [Inline] {
        advance(by: "![")
        let labelStart = position

        guard let closingBracket = findClosingBracket(startingAt: labelStart) else {
            position = source.endIndex
            return makeMalformedLabelInlines(from: labelStart)
        }

        let alt = makeLabelInlines(in: labelStart..<closingBracket)
        position = source.index(after: closingBracket)

        guard position < source.endIndex,
              source[position] == "("
        else {
            return alt
        }

        advance()
        let destinationStart = position

        guard let destinationEnd = findClosingParenthesis(startingAt: destinationStart) else {
            advancePastIncompleteDestination()
            return alt
        }

        let sourceURL = String(source[destinationStart..<destinationEnd])
        position = source.index(after: destinationEnd)
        return [.image(source: sourceURL, title: nil, alt: alt)]
    }

    mutating func parseLinkInlines() -> [Inline] {
        advance()
        let labelStart = position

        guard let closingBracket = findClosingBracket(startingAt: labelStart) else {
            position = source.endIndex
            return makeMalformedLabelInlines(from: labelStart)
        }

        let children = makeLabelInlines(in: labelStart..<closingBracket)
        position = source.index(after: closingBracket)

        guard position < source.endIndex,
              source[position] == "("
        else {
            return children
        }

        advance()
        let destinationStart = position

        guard let destinationEnd = findClosingParenthesis(startingAt: destinationStart) else {
            advancePastIncompleteDestination()
            return children
        }

        let destination = String(source[destinationStart..<destinationEnd])
        position = source.index(after: destinationEnd)
        return [.link(destination: destination, children: children)]
    }

    mutating func parseStrikethroughInlines() -> [Inline] {
        parseDelimitedInlines(delimiter: .strikethrough) { .strikethrough($0) }
    }

    mutating func parseStrongInlines() -> [Inline] {
        parseDelimitedInlines(delimiter: .strong) { .strong($0) }
    }

    func appendText(_ text: String, to inlines: inout [Inline]) {
        guard !text.isEmpty else { return }
        inlines.append(.text(text))
    }
}
