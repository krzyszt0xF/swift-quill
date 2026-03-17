package enum InlineParser {
    package static func parse(_ text: String) -> [Inline] {
        var parser = Parser(source: text[...])
        return parser.makeParsedInlines()
    }
}

extension InlineParser {
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

extension InlineParser.Parser {
    mutating func makeParsedInlines() -> [Inline] {
        InlineScanner.makeCoalescedInlines(from: parse(until: nil).inlines)
    }

    mutating func parse(until delimiter: InlineParser.Delimiter?) -> InlineParser.ParseResult {
        var inlines: [Inline] = []
        var textBuffer = ""

        while position < source.endIndex {
            if let delimiter,
               InlineDelimiterParser.checkClosingDelimiter(delimiter, in: self) {
                appendText(textBuffer, to: &inlines)
                InlineScanner.advance(&self, by: delimiter.token)
                return InlineParser.ParseResult(
                    didReachDelimiter: true,
                    inlines: inlines
                )
            }

            if InlineScanner.checkTokenPrefix("![", in: self) {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: InlineLinkParser.parseImageInlines(&self))
                continue
            }

            if InlineScanner.checkTokenPrefix("**", in: self) {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: InlineDelimiterParser.parseStrongInlines(&self))
                continue
            }

            if InlineScanner.checkTokenPrefix("~~", in: self) {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: InlineDelimiterParser.parseStrikethroughInlines(&self))
                continue
            }

            if InlineScanner.checkTokenPrefix("`", in: self) {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(parseBacktickInline())
                continue
            }

            if InlineScanner.checkTokenPrefix("[", in: self) {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: InlineLinkParser.parseLinkInlines(&self))
                continue
            }

            if InlineScanner.checkTokenPrefix("*", in: self),
               InlineScanner.checkCanStartEmphasis(self) {
                appendText(textBuffer, to: &inlines)
                textBuffer = ""
                inlines.append(contentsOf: InlineDelimiterParser.parseEmphasisInlines(&self))
                continue
            }

            textBuffer.append(source[position])
            InlineScanner.advance(&self)
        }

        appendText(textBuffer, to: &inlines)
        return InlineParser.ParseResult(
            didReachDelimiter: false,
            inlines: inlines
        )
    }
}

private extension InlineParser.Parser {
    mutating func parseBacktickInline() -> Inline {
        InlineScanner.advance(&self)

        guard let closingIndex = source[position...].firstIndex(of: "`") else {
            let code = String(source[position...])
            position = source.endIndex
            return .code(code)
        }

        let code = String(source[position..<closingIndex])
        position = source.index(after: closingIndex)
        return .code(code)
    }

    func appendText(_ text: String, to inlines: inout [Inline]) {
        guard !text.isEmpty else { return }
        inlines.append(.text(text))
    }
}
