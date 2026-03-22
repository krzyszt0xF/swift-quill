package enum BlockReducer {
    package static func apply(_ event: ParserEvent, to state: inout ReducerState) {
        while state.blocks.count > state.frozenCount {
            state.blocks.removeLast()
        }

        switch event {
        case let .codeBlockText(text):
            handleCodeBlockText(text, state: &state)
        case .endBlockQuote:
            handleEndBlockQuote(state: &state)
        case .endCodeBlock:
            handleEndCodeBlock(state: &state)
        case .endEmphasis, .endInlineCode, .endLink, .endStrikethrough, .endStrong:
            closeInlineFrame(state: &state)
        case .endHeading:
            handleEndHeading(state: &state)
        case .endList:
            handleEndList(state: &state)
        case .endListItem:
            handleEndListItem(state: &state)
        case .endParagraph:
            handleEndParagraph(state: &state)
        case .endTable:
            handleEndTable(state: &state)
        case let .image(source, title, alt):
            appendInline(.image(source: source, title: title, alt: [.text(alt)]), state: &state)
        case .startBlockQuote:
            state.contextStack.append(state.currentContext)
            state.currentContext = .blockquote(
                children: [],
                id: state.identityGenerator.makeIdentity()
            )
        case let .startCodeBlock(language):
            state.contextStack.append(state.currentContext)
            state.currentContext = .codeBlock(
                language: language,
                code: "",
                id: state.identityGenerator.makeIdentity()
            )
        case .startEmphasis:
            pushInlineFrame(.emphasis, state: &state)
        case let .startHeading(level):
            state.contextStack.append(state.currentContext)
            state.currentContext = .heading(
                level: level,
                id: state.identityGenerator.makeIdentity()
            )
        case .startInlineCode:
            pushInlineFrame(.code, state: &state)
        case let .startLink(destination):
            pushInlineFrame(.link(destination: destination), state: &state)
        case let .startList(ordered):
            state.contextStack.append(state.currentContext)
            state.currentContext = .list(
                id: state.identityGenerator.makeIdentity(),
                ordered: ordered,
                items: []
            )
        case .startListItem:
            state.contextStack.append(state.currentContext)
            state.currentContext = .listItem(blocks: [], checkbox: nil)
        case let .startTaskListItem(checkbox):
            state.contextStack.append(state.currentContext)
            state.currentContext = .listItem(blocks: [], checkbox: checkbox)
        case .startParagraph:
            state.contextStack.append(state.currentContext)
            state.currentContext = .paragraph(id: state.identityGenerator.makeIdentity())
        case .startStrikethrough:
            pushInlineFrame(.strikethrough, state: &state)
        case .startStrong:
            pushInlineFrame(.strong, state: &state)
        case .startTable:
            state.contextStack.append(state.currentContext)
            state.currentContext = .table(
                id: state.identityGenerator.makeIdentity(),
                rows: []
            )
        case let .tableRow(cells):
            handleTableRow(cells, state: &state)
        case let .text(string):
            appendInline(.text(string), state: &state)
        case .thematicBreak:
            emitBlock(makeBlockNode(.thematicBreak, state: &state), state: &state)
        }
    }
}

package extension BlockReducer {
    struct ReducerState: Sendable {
        package var blocks: [BlockNode] = []
        package var frozenCount: Int = 0

        var contextStack: [OpenContext] = []
        var currentContext: OpenContext = .topLevel
        var identityGenerator = BlockIdentityGenerator()
        var inlineStack: [InlineFrame] = []
        var currentInlines: [Inline] = []

        package init() {}
    }
}

extension BlockReducer {
    enum OpenContext: Sendable {
        case blockquote(children: [BlockNode], id: BlockIdentity)
        case codeBlock(language: String?, code: String, id: BlockIdentity)
        case heading(level: Int, id: BlockIdentity)
        case list(id: BlockIdentity, ordered: Bool, items: [Block.ListItem])
        case listItem(blocks: [BlockNode], checkbox: Block.Checkbox?)
        case paragraph(id: BlockIdentity)
        case table(id: BlockIdentity, rows: [[String]])
        case topLevel
    }

    enum InlineKind: Sendable {
        case code
        case emphasis
        case link(destination: String)
        case strikethrough
        case strong
    }

    struct InlineFrame: Sendable {
        let kind: InlineKind
        let savedInlines: [Inline]
    }

    static func wrapInline(_ kind: InlineKind, children: [Inline]) -> Inline {
        switch kind {
        case .code:
            let text = children
                .compactMap { if case let .text(content) = $0 { content } else { nil } }
                .joined()
            return .code(text)
        case .emphasis:
            return .emphasis(children)
        case let .link(destination):
            return .link(destination: destination, children: children)
        case .strikethrough:
            return .strikethrough(children)
        case .strong:
            return .strong(children)
        }
    }
}

// MARK: - Event Handlers

private extension BlockReducer {
    static func emitBlock(_ node: BlockNode, state: inout ReducerState) {
        switch state.currentContext {
        case .blockquote(var children, let id):
            children.append(node)
            state.currentContext = .blockquote(children: children, id: id)
        case .listItem(var blocks, let checkbox):
            blocks.append(node)
            state.currentContext = .listItem(blocks: blocks, checkbox: checkbox)
        case .topLevel:
            state.blocks.append(node)
            state.frozenCount += 1
        default:
            break
        }
    }

    static func handleEndBlockQuote(state: inout ReducerState) {
        guard case let .blockquote(children, id) = state.currentContext else { return }

        state.currentContext = state.contextStack.removeLast()
        emitBlock(BlockNode(block: .blockquote(children: children), id: id), state: &state)
    }

    static func handleEndCodeBlock(state: inout ReducerState) {
        guard case let .codeBlock(language, code, id) = state.currentContext else { return }

        state.currentContext = state.contextStack.removeLast()
        emitBlock(BlockNode(block: .codeBlock(language: language, code: code), id: id), state: &state)
    }

    static func handleEndHeading(state: inout ReducerState) {
        guard case let .heading(level, id) = state.currentContext else { return }

        let inlines = state.currentInlines
        state.currentInlines = []
        state.currentContext = state.contextStack.removeLast()
        emitBlock(
            BlockNode(
                block: .heading(
                    level: level,
                    content: InlineRenderNormalizer.makeRenderedInlines(from: inlines)
                ),
                id: id
            ),
            state: &state
        )
    }

    static func handleEndList(state: inout ReducerState) {
        guard case let .list(id, ordered, items) = state.currentContext else { return }

        state.currentContext = state.contextStack.removeLast()
        if ordered {
            emitBlock(BlockNode(block: .orderedList(startIndex: 1, items: items), id: id), state: &state)
        } else {
            emitBlock(BlockNode(block: .unorderedList(items: items), id: id), state: &state)
        }
    }

    static func handleEndListItem(state: inout ReducerState) {
        guard case let .listItem(blocks, checkbox) = state.currentContext else { return }
        
        state.currentContext = state.contextStack.removeLast()
        guard case .list(let id, let ordered, var items) = state.currentContext else { return }
        
        items.append(Block.ListItem(checkbox: checkbox, children: blocks))
        state.currentContext = .list(id: id, ordered: ordered, items: items)
    }

    static func handleEndParagraph(state: inout ReducerState) {
        guard case let .paragraph(id) = state.currentContext else { return }
        let inlines = state.currentInlines
        state.currentInlines = []
        state.currentContext = state.contextStack.removeLast()
        emitBlock(
            BlockNode(
                block: .paragraph(content: InlineRenderNormalizer.makeRenderedInlines(from: inlines)),
                id: id
            ),
            state: &state
        )
    }

    static func handleEndTable(state: inout ReducerState) {
        guard case let .table(id, rows) = state.currentContext else { return }
        
        state.currentContext = state.contextStack.removeLast()
        guard let headerCells = rows.first else {
            emitBlock(
                BlockNode(
                    block: .table(columnAlignments: [], header: Block.TableRow(cells: []), rows: []),
                    id: id
                ),
                state: &state
            )
            return
        }

        let header = Block.TableRow(cells: headerCells.map { Block.TableCell(content: [.text($0)]) })
        let dataRows = rows.dropFirst().map { row in
            Block.TableRow(cells: row.map { Block.TableCell(content: [.text($0)]) })
        }
        emitBlock(
            BlockNode(
                block: .table(columnAlignments: [], header: header, rows: dataRows),
                id: id
            ),
            state: &state
        )
    }
}

// MARK: - Content Accumulation

private extension BlockReducer {
    static func handleCodeBlockText(_ text: String, state: inout ReducerState) {
        guard case let .codeBlock(language, code, id) = state.currentContext else { return }

        state.currentContext = .codeBlock(language: language, code: code + text, id: id)
    }

    static func handleTableRow(_ cells: [String], state: inout ReducerState) {
        guard case let .table(id, rows) = state.currentContext else { return }

        state.currentContext = .table(id: id, rows: rows + [cells])
    }

    static func makeBlockNode(_ block: Block, state: inout ReducerState) -> BlockNode {
        BlockNode(block: block, id: state.identityGenerator.makeIdentity())
    }
}

// MARK: - Inline Stack

private extension BlockReducer {
    static func appendInline(_ inline: Inline, state: inout ReducerState) {
        state.currentInlines.append(inline)
    }

    static func closeInlineFrame(state: inout ReducerState) {
        guard let frame = state.inlineStack.popLast() else { return }
        
        let children = state.currentInlines
        state.currentInlines = frame.savedInlines
        state.currentInlines.append(wrapInline(frame.kind, children: children))
    }

    static func pushInlineFrame(_ kind: InlineKind, state: inout ReducerState) {
        state.inlineStack.append(InlineFrame(kind: kind, savedInlines: state.currentInlines))
        state.currentInlines = []
    }
}
