struct RenderContext {
    let highlightStore: (any CodeBlockHighlightStore)?
    let imageLoadStore: (any ImageLoadStore)?
    let rendersAttachments: Bool
    let theme: QuillTheme
}

struct NestingContext {
    let blockquoteDepth: Int
    let listLevel: Int

    static let root = NestingContext(blockquoteDepth: 0, listLevel: 0)

    func incrementingBlockquoteDepth() -> NestingContext {
        NestingContext(
            blockquoteDepth: blockquoteDepth + 1,
            listLevel: 0
        )
    }

    func incrementingListLevel() -> NestingContext {
        NestingContext(
            blockquoteDepth: blockquoteDepth,
            listLevel: listLevel + 1
        )
    }
}
