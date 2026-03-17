enum InlineLinkParser {
    static func parseImageInlines(_ parser: inout InlineParser.Parser) -> [Inline] {
        InlineScanner.advance(&parser, by: "![")
        let labelStart = parser.position

        guard let closingBracket = InlineScanner.findClosingBracket(startingAt: labelStart, in: parser) else {
            parser.position = parser.source.endIndex
            return makeMalformedLabelInlines(from: labelStart, in: parser)
        }

        let alt = makeLabelInlines(in: labelStart..<closingBracket, source: parser.source)
        parser.position = parser.source.index(after: closingBracket)

        guard parser.position < parser.source.endIndex,
              parser.source[parser.position] == "("
        else {
            return alt
        }

        InlineScanner.advance(&parser)
        let destinationStart = parser.position

        guard let destinationEnd = InlineScanner.findClosingParenthesis(startingAt: destinationStart, in: parser) else {
            InlineScanner.advancePastIncompleteDestination(&parser)
            return alt
        }

        let sourceURL = String(parser.source[destinationStart..<destinationEnd])
        parser.position = parser.source.index(after: destinationEnd)
        return [.image(source: sourceURL, title: nil, alt: alt)]
    }

    static func parseLinkInlines(_ parser: inout InlineParser.Parser) -> [Inline] {
        InlineScanner.advance(&parser)
        let labelStart = parser.position

        guard let closingBracket = InlineScanner.findClosingBracket(startingAt: labelStart, in: parser) else {
            parser.position = parser.source.endIndex
            return makeMalformedLabelInlines(from: labelStart, in: parser)
        }

        let children = makeLabelInlines(in: labelStart..<closingBracket, source: parser.source)
        parser.position = parser.source.index(after: closingBracket)

        guard parser.position < parser.source.endIndex,
              parser.source[parser.position] == "("
        else {
            return children
        }

        InlineScanner.advance(&parser)
        let destinationStart = parser.position

        guard let destinationEnd = InlineScanner.findClosingParenthesis(startingAt: destinationStart, in: parser) else {
            InlineScanner.advancePastIncompleteDestination(&parser)
            return children
        }

        let destination = String(parser.source[destinationStart..<destinationEnd])
        parser.position = parser.source.index(after: destinationEnd)
        return [.link(destination: destination, children: children)]
    }
}

private extension InlineLinkParser {
    static func makeLabelInlines(in range: Range<Substring.Index>, source: Substring) -> [Inline] {
        InlineParser.parse(String(source[range]))
    }

    static func makeMalformedLabelInlines(from start: Substring.Index, in parser: InlineParser.Parser) -> [Inline] {
        InlineParser.parse(String(parser.source[start...]))
    }
}
