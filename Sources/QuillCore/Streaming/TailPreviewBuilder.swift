enum TailPreviewBuilder {
    enum TailPart {
        case block(Block)
        case listItem(Block.ListItem)
        case none
    }

    static func buildTailPreview(state: BlockReducer.ReducerState) -> Block? {
        if case .topLevel = state.currentContext { return nil }

        var part = innerPart(
            from: state.currentContext,
            inlines: state.currentInlines,
            inlineStack: state.inlineStack
        )

        for context in state.contextStack.reversed() {
            switch context {
            case let .blockquote(children):
                var all = children
                if case let .block(block) = part { all.append(block) }
                part = .block(.blockquote(children: all))
                
            case .codeBlock, .heading, .paragraph, .table:
                break
                
            case let .list(ordered, items):
                var all = items
                if case let .listItem(item) = part { all.append(item) }
                part = ordered
                    ? .block(.orderedList(startIndex: 1, items: all))
                    : .block(.unorderedList(items: all))
                
            case let .listItem(blocks, checkbox):
                var all = blocks
                if case let .block(block) = part { all.append(block) }
                part = .listItem(Block.ListItem(checkbox: checkbox, children: all))
                
            case .topLevel:
                break
            }
            
            if case .topLevel = context { break }
        }

        if case let .block(block) = part { return block }
        
        return nil
    }
}

private extension TailPreviewBuilder {
    static func collapseInlineStack(current: [Inline], stack: [BlockReducer.InlineFrame]) -> [Inline] {
        var result = current
        for frame in stack.reversed() {
            result = frame.savedInlines + [BlockReducer.wrapInline(frame.kind, children: result)]
        }
        
        return result
    }

    static func innerPart(
        from context: BlockReducer.OpenContext,
        inlines: [Inline],
        inlineStack: [BlockReducer.InlineFrame]
    ) -> TailPart {
        switch context {
        case let .blockquote(children):
            return .block(.blockquote(children: children))
        case let .codeBlock(language, code):
            return .block(.codeBlock(language: language, code: code))
        case let .heading(level):
            let parsed = InlineRenderNormalizer.makeRenderedInlines(from: inlines)
            let preview = collapseInlineStack(current: parsed, stack: inlineStack)
            return preview.isEmpty ? .none : .block(.heading(level: level, content: preview))
        case let .list(ordered, items):
            guard !items.isEmpty else { return .none }
            return ordered
                ? .block(.orderedList(startIndex: 1, items: items))
                : .block(.unorderedList(items: items))
        case let .listItem(blocks, checkbox):
            return .listItem(Block.ListItem(checkbox: checkbox, children: blocks))
        case .paragraph:
            let parsed = InlineRenderNormalizer.makeRenderedInlines(from: inlines)
            let preview = collapseInlineStack(current: parsed, stack: inlineStack)
            return preview.isEmpty ? .none : .block(.paragraph(content: preview))
        case let .table(rows):
            return tablePreview(from: rows)
        case .topLevel:
            return .none
        }
    }

    static func tablePreview(from rows: [[String]]) -> TailPart {
        guard let headerCells = rows.first else { return .none }
        
        let header = Block.TableRow(cells: headerCells.map { Block.TableCell(content: [.text($0)]) })
        let dataRows = rows.dropFirst().map { row in
            Block.TableRow(cells: row.map { Block.TableCell(content: [.text($0)]) })
        }
        return .block(.table(columnAlignments: [], header: header, rows: dataRows))
    }
}
