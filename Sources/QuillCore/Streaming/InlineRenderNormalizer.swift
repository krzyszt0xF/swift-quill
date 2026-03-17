enum InlineRenderNormalizer {
    static func makeRenderedInlines(from inlines: [Inline]) -> [Inline] {
        guard let rawText = makeRawInlineText(from: inlines) else { return inlines }
        guard !rawText.isEmpty else { return inlines }
        return InlineParser.parse(rawText)
    }
}

private extension InlineRenderNormalizer {
    static func makeRawInlineText(from inlines: [Inline]) -> String? {
        var result = ""
        for inline in inlines {
            guard case let .text(content) = inline else { return nil }
            result += content
        }
        return result
    }
}
