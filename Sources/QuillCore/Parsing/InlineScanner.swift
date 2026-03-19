enum InlineScanner {
    static func advance(_ parser: inout InlineParser.Parser) {
        parser.position = parser.source.index(after: parser.position)
    }

    static func advance(_ parser: inout InlineParser.Parser, by token: String) {
        for _ in token {
            guard parser.position < parser.source.endIndex else { return }
            
            advance(&parser)
        }
    }

    static func advancePastIncompleteDestination(_ parser: inout InlineParser.Parser) {
        while parser.position < parser.source.endIndex {
            guard !checkWhitespace(parser.source[parser.position]) else { return }
            
            advance(&parser)
        }
    }

    static func checkCanStartEmphasis(_ parser: InlineParser.Parser) -> Bool {
        let nextPosition = parser.source.index(after: parser.position)
        guard nextPosition < parser.source.endIndex else { return false }
        
        return !checkWhitespace(parser.source[nextPosition])
    }

    static func checkTokenPrefix(_ token: String, in parser: InlineParser.Parser) -> Bool {
        parser.source[parser.position...].hasPrefix(token)
    }

    static func checkWhitespace(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy(\.properties.isWhitespace)
    }

    static func findClosingBracket(startingAt start: Substring.Index, in parser: InlineParser.Parser) -> Substring.Index? {
        var bracketDepth = 0
        var searchIndex = start

        while searchIndex < parser.source.endIndex {
            switch parser.source[searchIndex] {
            case "[":
                bracketDepth += 1
            case "]":
                guard bracketDepth > 0 else { return searchIndex }
                bracketDepth -= 1
            default:
                break
            }
            searchIndex = parser.source.index(after: searchIndex)
        }

        return nil
    }

    static func findClosingParenthesis(startingAt start: Substring.Index, in parser: InlineParser.Parser) -> Substring.Index? {
        var searchIndex = start

        while searchIndex < parser.source.endIndex {
            guard parser.source[searchIndex] != ")" else { return searchIndex }
            searchIndex = parser.source.index(after: searchIndex)
        }

        return nil
    }

    static func makeCoalescedInlines(from inlines: [Inline]) -> [Inline] {
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
}
