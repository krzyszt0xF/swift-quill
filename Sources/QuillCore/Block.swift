package indirect enum Block: Equatable, Sendable {
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

package extension Block {
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
        package let checkbox: Checkbox?
        package let children: [Block]

        package init(checkbox: Checkbox? = nil, children: [Block]) {
            self.checkbox = checkbox
            self.children = children
        }
    }

    struct TableCell: Equatable, Sendable {
        package let content: [Inline]

        package init(content: [Inline]) {
            self.content = content
        }
    }

    struct TableRow: Equatable, Sendable {
        package let cells: [TableCell]

        package init(cells: [TableCell]) {
            self.cells = cells
        }
    }
}
