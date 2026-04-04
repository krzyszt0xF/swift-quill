package indirect enum Block: Equatable, Sendable {
    case blockquote(children: [BlockNode])
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

package struct BlockIdentity: Hashable, Sendable {
    package let rawValue: UInt64

    package init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
}

package struct BlockNode: Equatable, Identifiable, Sendable {
    package let block: Block
    package let id: BlockIdentity

    package init(block: Block, id: BlockIdentity) {
        self.block = block
        self.id = id
    }
}

package struct BlockIdentityGenerator: Sendable {
    private var nextRawValue: UInt64

    package init(nextRawValue: UInt64 = 0) {
        self.nextRawValue = nextRawValue
    }

    package mutating func makeIdentity() -> BlockIdentity {
        let identity = BlockIdentity(rawValue: nextRawValue)
        nextRawValue += 1
        return identity
    }
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
        package let children: [BlockNode]

        package init(checkbox: Checkbox? = nil, children: [BlockNode]) {
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
