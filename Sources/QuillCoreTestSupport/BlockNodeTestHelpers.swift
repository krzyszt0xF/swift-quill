import QuillCore

package extension Array where Element == Block {
    func canonicalBlocks() -> [Block] {
        makeNodes().normalizedBlocks()
    }

    func makeNodes() -> [BlockNode] {
        var nextRawValue: UInt64 = 0
        return map { makeNode(from: $0, nextRawValue: &nextRawValue) }
    }
}

package extension Array where Element == BlockNode {
    func normalizedBlocks() -> [Block] {
        map { normalizedBlock(from: $0.block) }
    }
}

package extension Block {
    static func makeBlockquote(_ blocks: Block...) -> Block {
        .blockquote(children: blocks.makeNodes())
    }

    static func makeBlockquote(_ blocks: [Block]) -> Block {
        .blockquote(children: blocks.makeNodes())
    }

    static func makeNodes(_ blocks: Block...) -> [BlockNode] {
        blocks.makeNodes()
    }
}

package extension Block.ListItem {
    init(checkbox: Block.Checkbox? = nil, blocks: Block...) {
        self.init(checkbox: checkbox, children: blocks.makeNodes())
    }

    init(checkbox: Block.Checkbox? = nil, blocks: [Block]) {
        self.init(checkbox: checkbox, children: blocks.makeNodes())
    }
}

private func makeItem(from item: Block.ListItem, nextRawValue: inout UInt64) -> Block.ListItem {
    Block.ListItem(
        checkbox: item.checkbox,
        children: item.children.map { makeNode(from: $0.block, nextRawValue: &nextRawValue) }
    )
}

private func makeNode(from block: Block, nextRawValue: inout UInt64) -> BlockNode {
    let id = BlockIdentity(rawValue: nextRawValue)
    nextRawValue += 1

    return BlockNode(
        block: normalizedBlock(from: block, nextRawValue: &nextRawValue),
        id: id
    )
}

private func normalizedBlock(from block: Block) -> Block {
    var nextRawValue: UInt64 = 0
    return normalizedBlock(from: block, nextRawValue: &nextRawValue)
}

private func normalizedBlock(from block: Block, nextRawValue: inout UInt64) -> Block {
    switch block {
    case let .blockquote(children):
        return .blockquote(children: children.map { makeNode(from: $0.block, nextRawValue: &nextRawValue) })
    case let .codeBlock(language, code):
        return .codeBlock(language: language, code: code)
    case let .heading(level, content):
        return .heading(level: level, content: content)
    case let .htmlBlock(rawHTML):
        return .htmlBlock(rawHTML: rawHTML)
    case let .orderedList(startIndex, items):
        return .orderedList(
            startIndex: startIndex,
            items: items.map { makeItem(from: $0, nextRawValue: &nextRawValue) }
        )
    case let .paragraph(content):
        return .paragraph(content: content)
    case let .table(columnAlignments, header, rows):
        return .table(columnAlignments: columnAlignments, header: header, rows: rows)
    case .thematicBreak:
        return .thematicBreak
    case let .unorderedList(items):
        return .unorderedList(items: items.map { makeItem(from: $0, nextRawValue: &nextRawValue) })
    }
}
