/// Converts a sequence of ParserEvents into the Block/Inline AST.
public enum BlockReducer {
    public static func apply(_ event: ParserEvent, to state: inout ReducerState) {
        switch event {
        case .codeBlockText(let text):
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
            state.currentContext = .blockquote(children: [])
        case let .startCodeBlock(language):
            state.contextStack.append(state.currentContext)
            state.currentContext = .codeBlock(language: language, code: "")
        case .startEmphasis:
            pushInlineFrame(.emphasis, state: &state)
        case let .startHeading(level):
            state.contextStack.append(state.currentContext)
            state.currentContext = .heading(level: level)
        case .startInlineCode:
            pushInlineFrame(.code, state: &state)
        case let .startLink(destination):
            pushInlineFrame(.link(destination: destination), state: &state)
        case let .startList(ordered):
            state.contextStack.append(state.currentContext)
            state.currentContext = .list(ordered: ordered, items: [])
        case .startListItem:
            state.contextStack.append(state.currentContext)
            state.currentContext = .listItem(blocks: [])
        case .startParagraph:
            state.contextStack.append(state.currentContext)
            state.currentContext = .paragraph
        case .startStrikethrough:
            pushInlineFrame(.strikethrough, state: &state)
        case .startStrong:
            pushInlineFrame(.strong, state: &state)
        case .startTable:
            state.contextStack.append(state.currentContext)
            state.currentContext = .table(rows: [])
        case let .tableRow(cells):
            handleTableRow(cells, state: &state)
        case let .text(string):
            appendInline(.text(string), state: &state)
        case .thematicBreak:
            emitBlock(.thematicBreak, state: &state)
        }
    }
}

public extension BlockReducer {
    struct ReducerState: Sendable {
        public var blocks: [Block] = []
        public var frozenCount: Int = 0

        var contextStack: [OpenContext] = []
        var currentContext: OpenContext = .topLevel
        var inlineStack: [InlineFrame] = []
        var currentInlines: [Inline] = []

        public init() {}
    }
}

extension BlockReducer {
    enum OpenContext: Sendable {
        case blockquote(children: [Block])
        case codeBlock(language: String?, code: String)
        case heading(level: Int)
        case list(ordered: Bool, items: [Block.ListItem])
        case listItem(blocks: [Block])
        case paragraph
        case table(rows: [[String]])
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
}

private extension BlockReducer {
    static func emitBlock(_ block: Block, state: inout ReducerState) {
        switch state.currentContext {
        case .blockquote(var children):
            children.append(block)
            state.currentContext = .blockquote(children: children)
        case .listItem(var blocks):
            blocks.append(block)
            state.currentContext = .listItem(blocks: blocks)
        case .topLevel:
            state.blocks.append(block)
            state.frozenCount += 1
        default:
            break
        }
    }

    static func handleEndBlockQuote(state: inout ReducerState) {
        guard case let .blockquote(children) = state.currentContext else { return }
        
        state.currentContext = state.contextStack.removeLast()
        emitBlock(.blockquote(children: children), state: &state)
    }

    static func handleEndCodeBlock(state: inout ReducerState) {
        guard case let .codeBlock(language, code) = state.currentContext else { return }
        
        state.currentContext = state.contextStack.removeLast()
        emitBlock(.codeBlock(language: language, code: code), state: &state)
    }

    static func handleEndHeading(state: inout ReducerState) {
        guard case let .heading(level) = state.currentContext else { return }
        
        let inlines = state.currentInlines
        state.currentInlines = []
        state.currentContext = state.contextStack.removeLast()
        emitBlock(.heading(level: level, content: inlines), state: &state)
    }

    static func handleEndList(state: inout ReducerState) {
        guard case let .list(ordered, items) = state.currentContext else { return }
        
        state.currentContext = state.contextStack.removeLast()
        if ordered {
            emitBlock(.orderedList(startIndex: 1, items: items), state: &state)
        } else {
            emitBlock(.unorderedList(items: items), state: &state)
        }
    }

    static func handleEndListItem(state: inout ReducerState) {
        guard case let .listItem(blocks) = state.currentContext else { return }
        state.currentContext = state.contextStack.removeLast()
        
        guard case .list(let ordered, var items) = state.currentContext else { return }
        items.append(Block.ListItem(children: blocks))
        state.currentContext = .list(ordered: ordered, items: items)
    }

    static func handleEndParagraph(state: inout ReducerState) {
        guard case .paragraph = state.currentContext else { return }
        let inlines = state.currentInlines
        state.currentInlines = []
        state.currentContext = state.contextStack.removeLast()
        emitBlock(.paragraph(content: inlines), state: &state)
    }

    static func handleEndTable(state: inout ReducerState) {
        guard case let .table(rows) = state.currentContext else { return }
        state.currentContext = state.contextStack.removeLast()

        guard let headerCells = rows.first else {
            emitBlock(.table(columnAlignments: [], header: Block.TableRow(cells: []), rows: []), state: &state)
            return
        }

        let header = Block.TableRow(cells: headerCells.map { Block.TableCell(content: [.text($0)]) })
        let dataRows = rows.dropFirst().map { row in
            Block.TableRow(cells: row.map { Block.TableCell(content: [.text($0)]) })
        }
        emitBlock(.table(columnAlignments: [], header: header, rows: dataRows), state: &state)
    }
}

// MARK: - Content Accumulation

private extension BlockReducer {
    static func handleCodeBlockText(_ text: String, state: inout ReducerState) {
        guard case let .codeBlock(language, code) = state.currentContext else { return }
        
        state.currentContext = .codeBlock(language: language, code: code + text)
    }

    static func handleTableRow(_ cells: [String], state: inout ReducerState) {
        guard case .table(var rows) = state.currentContext else { return }
        
        rows.append(cells)
        state.currentContext = .table(rows: rows)
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

        let wrapped: Inline
        switch frame.kind {
        case .code:
            let text = children.map { inline -> String in
                if case let .text(content) = inline { return content }
                return ""
            }.joined()
            wrapped = .code(text)
        case .emphasis:
            wrapped = .emphasis(children)
        case .link(let destination):
            wrapped = .link(destination: destination, children: children)
        case .strikethrough:
            wrapped = .strikethrough(children)
        case .strong:
            wrapped = .strong(children)
        }
        state.currentInlines.append(wrapped)
    }

    static func pushInlineFrame(_ kind: InlineKind, state: inout ReducerState) {
        state.inlineStack.append(InlineFrame(kind: kind, savedInlines: state.currentInlines))
        state.currentInlines = []
    }
}
