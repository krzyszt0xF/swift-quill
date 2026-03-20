enum InlineDelimiterParser {
    static func checkClosingDelimiter(
        _ delimiter: InlineParser.Delimiter,
        in parser: InlineParser.Parser
    ) -> Bool {
        switch delimiter {
        case .emphasis:
            return InlineScanner.checkTokenPrefix("*", in: parser)
                && (!InlineScanner.checkTokenPrefix("**", in: parser)
                    || InlineScanner.checkTokenPrefix("***", in: parser))
        case .strikethrough, .strong:
            return InlineScanner.checkTokenPrefix(delimiter.token, in: parser)
        }
    }

    static func parseDelimitedInlines(
        _ parser: inout InlineParser.Parser,
        delimiter: InlineParser.Delimiter,
        makeInline: ([Inline]) -> Inline
    ) -> [Inline] {
        InlineScanner.advance(&parser, by: delimiter.token)
        let result = parser.parse(until: delimiter)

        guard result.didReachDelimiter else {
            return result.inlines
        }

        return [makeInline(result.inlines)]
    }

    static func parseEmphasisInlines(_ parser: inout InlineParser.Parser) -> [Inline] {
        parseDelimitedInlines(&parser, delimiter: .emphasis) { .emphasis($0) }
    }

    static func parseStrikethroughInlines(_ parser: inout InlineParser.Parser) -> [Inline] {
        parseDelimitedInlines(&parser, delimiter: .strikethrough) { .strikethrough($0) }
    }

    static func parseStrongInlines(_ parser: inout InlineParser.Parser) -> [Inline] {
        parseDelimitedInlines(&parser, delimiter: .strong) { .strong($0) }
    }
}
