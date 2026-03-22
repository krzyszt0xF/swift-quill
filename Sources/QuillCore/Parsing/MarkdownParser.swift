import Markdown

package struct MarkdownParser: Sendable {
    package var parse: @Sendable (String) -> [BlockNode]

    package init(parse: @escaping @Sendable (String) -> [BlockNode]) {
        self.parse = parse
    }
}

package extension MarkdownParser {
    static let live = MarkdownParser { markdown in
        let document = Document(parsing: markdown)
        var visitor = BlockVisitor()
        
        return visitor.visit(document)
    }
}
