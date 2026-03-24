import Markdown

/// Maps swift-markdown's `Markup` AST to QuillCore's `Block`/`Inline` types.
struct BlockVisitor: MarkupVisitor {
    typealias Result = [BlockNode]

    private var identityGenerator = BlockIdentityGenerator()

    mutating func defaultVisit(_ markup: Markup) -> [BlockNode] {
        var blocks: [BlockNode] = []
        for child in markup.children {
            blocks.append(contentsOf: visit(child))
        }
        return blocks
    }

    mutating func visitDocument(_ document: Document) -> [BlockNode] {
        var blocks: [BlockNode] = []
        for child in document.children {
            blocks.append(contentsOf: visit(child))
        }
        return blocks
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> [BlockNode] {
        var children: [BlockNode] = []
        for child in blockQuote.children {
            children.append(contentsOf: visit(child))
        }
        return [makeBlockNode(.blockquote(children: children))]
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> [BlockNode] {
        [makeBlockNode(.codeBlock(language: codeBlock.language, code: codeBlock.code))]
    }

    mutating func visitHeading(_ heading: Heading) -> [BlockNode] {
        [makeBlockNode(.heading(level: heading.level, content: convertInlines(heading)))]
    }
    
    mutating func visitOrderedList(_ orderedList: OrderedList) -> [BlockNode] {
        var items: [Block.ListItem] = []
        for item in orderedList.listItems {
            var children: [BlockNode] = []
            for child in item.children {
                children.append(contentsOf: visit(child))
            }
            
            let checkbox = Block.Checkbox(from: item.checkbox)
            items.append(Block.ListItem(checkbox: checkbox, children: children))
        }
        
        return [makeBlockNode(.orderedList(startIndex: orderedList.startIndex, items: items))]
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> [BlockNode] {
        [makeBlockNode(.paragraph(content: convertInlines(paragraph)))]
    }
    
    mutating func visitTable(_ table: Table) -> [BlockNode] {
        let columnAlignments = table.columnAlignments.map { alignment -> Block.ColumnAlignment? in
            switch alignment {
            case .left: return .left
            case .center: return .center
            case .right: return .right
            default: return nil
            }
        }

        let headerRow = convert(tableHead: table.head)

        var bodyRows: [Block.TableRow] = []
        for row in table.body.rows {
            bodyRows.append(convert(tableRow: row))
        }

        return [makeBlockNode(.table(columnAlignments: columnAlignments, header: headerRow, rows: bodyRows))]
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> [BlockNode] {
        [makeBlockNode(.thematicBreak)]
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> [BlockNode] {
        var items: [Block.ListItem] = []
        
        for item in unorderedList.listItems {
            var children: [BlockNode] = []
            for child in item.children {
                children.append(contentsOf: visit(child))
            }
            
            let checkbox = Block.Checkbox(from: item.checkbox)
            items.append(Block.ListItem(checkbox: checkbox, children: children))
        }
        
        return [makeBlockNode(.unorderedList(items: items))]
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> [BlockNode] {
        [makeBlockNode(.htmlBlock(rawHTML: htmlBlock.rawHTML))]
    }
}

private extension BlockVisitor {
    mutating func makeBlockNode(_ block: Block) -> BlockNode {
        BlockNode(block: block, id: identityGenerator.makeIdentity())
    }

    func convert(tableHead: Table.Head) -> Block.TableRow {
        var cells: [Block.TableCell] = []
        for cell in tableHead.cells {
            cells.append(Block.TableCell(content: convertInlines(cell)))
        }
        
        return Block.TableRow(cells: cells)
    }

    func convert(tableRow: Table.Row) -> Block.TableRow {
        var cells: [Block.TableCell] = []
        for cell in tableRow.cells {
            cells.append(Block.TableCell(content: convertInlines(cell)))
        }
        
        return Block.TableRow(cells: cells)
    }

    func convertInline(_ markup: Markup) -> [Inline] {
        switch markup {
        case let code as InlineCode:
            return [.code(code.code)]
            
        case let emphasis as Emphasis:
            return [.emphasis(convertInlines(emphasis))]
            
        case let html as InlineHTML:
            return [.inlineHTML(html.rawHTML)]
            
        case let image as Markdown.Image:
            return [.image(
                source: image.source,
                title: image.title,
                alt: convertInlines(image))]
            
        case _ as LineBreak:
            return [.lineBreak]
            
        case let link as Link:
            return [.link(
                destination: link.destination ?? "",
                children: convertInlines(link))]
            
        case _ as SoftBreak:
            return [.text(" ")]
            
        case let strikethrough as Strikethrough:
            return [.strikethrough(convertInlines(strikethrough))]
            
        case let strong as Strong:
            return [.strong(convertInlines(strong))]
            
        case let text as Text:
            return [.text(text.string)]
        
        default:
            return convertInlines(markup)
        }
    }
    
    func convertInlines(_ container: some Markup) -> [Inline] {
        var inlines: [Inline] = []
        for child in container.children {
            inlines.append(contentsOf: convertInline(child))
        }
        
        return inlines
    }
}

private extension Block.Checkbox {
    init?(from checkbox: Markdown.Checkbox?) {
        guard let checkbox else {
            return nil
        }
        
        switch checkbox {
        case .checked:
            self = .checked
        case .unchecked:
            self = .unchecked
        }
    }
}
