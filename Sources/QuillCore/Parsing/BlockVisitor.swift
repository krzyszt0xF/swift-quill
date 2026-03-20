import Markdown

/// Maps swift-markdown's `Markup` AST to QuillCore's `Block`/`Inline` types.
struct BlockVisitor: MarkupVisitor {
    typealias Result = [Block]

    mutating func defaultVisit(_ markup: Markup) -> [Block] {
        var blocks: [Block] = []
        for child in markup.children {
            blocks.append(contentsOf: visit(child))
        }
        return blocks
    }

    mutating func visitDocument(_ document: Document) -> [Block] {
        var blocks: [Block] = []
        for child in document.children {
            blocks.append(contentsOf: visit(child))
        }
        return blocks
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> [Block] {
        var children: [Block] = []
        for child in blockQuote.children {
            children.append(contentsOf: visit(child))
        }
        return [.blockquote(children: children)]
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> [Block] {
        [.codeBlock(language: codeBlock.language, code: codeBlock.code)]
    }

    mutating func visitHeading(_ heading: Heading) -> [Block] {
        [.heading(level: heading.level, content: convertInlines(heading))]
    }
    
    mutating func visitOrderedList(_ orderedList: OrderedList) -> [Block] {
        var items: [Block.ListItem] = []
        for item in orderedList.listItems {
            var children: [Block] = []
            for child in item.children {
                children.append(contentsOf: visit(child))
            }
            
            let checkbox = Block.Checkbox(from: item.checkbox)
            items.append(Block.ListItem(checkbox: checkbox, children: children))
        }
        
        return [.orderedList(startIndex: orderedList.startIndex, items: items)]
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> [Block] {
        [.paragraph(content: convertInlines(paragraph))]
    }
    
    mutating func visitTable(_ table: Table) -> [Block] {
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

        return [.table(columnAlignments: columnAlignments, header: headerRow, rows: bodyRows)]
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> [Block] {
        [.thematicBreak]
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> [Block] {
        var items: [Block.ListItem] = []
        
        for item in unorderedList.listItems {
            var children: [Block] = []
            for child in item.children {
                children.append(contentsOf: visit(child))
            }
            
            let checkbox = Block.Checkbox(from: item.checkbox)
            items.append(Block.ListItem(checkbox: checkbox, children: children))
        }
        
        return [.unorderedList(items: items)]
    }

    mutating func visitHTMLBlock(_ htmlBlock: HTMLBlock) -> [Block] {
        [.htmlBlock(rawHTML: htmlBlock.rawHTML)]
    }
}

private extension BlockVisitor {
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
