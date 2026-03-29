package enum ParserEvent: Equatable, Sendable {
    case codeBlockText(String)
    case endBlockQuote
    case endCodeBlock
    case endEmphasis
    case endHeading
    case endInlineCode
    case endLink
    case endList
    case endListItem
    case endParagraph
    case endStrikethrough
    case endStrong
    case endTable
    case image(source: String?, title: String?, alt: String)
    case startBlockQuote
    case startCodeBlock(language: String?)
    case startEmphasis
    case startHeading(level: Int)
    case startInlineCode
    case startLink(destination: String)
    case startList(ordered: Bool)
    case startListItem
    case startTaskListItem(checkbox: Block.Checkbox)
    case startParagraph
    case startStrikethrough
    case startStrong
    case startTable
    case tableAlignments([Block.ColumnAlignment?])
    case tableRow([String])
    case text(String)
    case thematicBreak
}
