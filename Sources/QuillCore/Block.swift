/// A block-level element in a parsed markdown document.
///
/// Each case corresponds to a CommonMark or GFM block construct.
/// Produced by ``Parser`` and consumed by renderers.
public indirect enum Block: Equatable, Sendable {
    case blockquote(children: [Block])
    case codeBlock(language: String?, code: String)
    case heading(level: Int, content: [Inline])
    case htmlBlock(rawHTML: String)
    case orderedList(startIndex: UInt, items: [ListItem])
    case paragraph(content: [Inline])
    case table(columnAlignments: [ColumnAlignment?],
               header: TableRow,
               rows: [TableRow])
    case thematicBreak
    case unorderedList(items: [ListItem])
}

public extension Block {
    enum Checkbox: Equatable, Sendable {
        case checked
        case unchecked
    }

    enum ColumnAlignment: Equatable, Sendable {
        case center
        case left
        case right
    }
    
    struct ListItem: Equatable, Sendable {
        public let checkbox: Checkbox?
        public let children: [Block]

        public init(checkbox: Checkbox? = nil, children: [Block]) {
            self.checkbox = checkbox
            self.children = children
        }
    }
    
    struct TableCell: Equatable, Sendable {
        public let content: [Inline]

        public init(content: [Inline]) {
            self.content = content
        }
    }

    struct TableRow: Equatable, Sendable {
        public let cells: [TableCell]
        
        public init(cells: [TableCell]) {
            self.cells = cells
        }
    }
}
