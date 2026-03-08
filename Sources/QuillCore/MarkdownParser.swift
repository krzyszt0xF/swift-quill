import Markdown

/// Closure-based markdown parser converting strings into `[Block]`.
public struct MarkdownParser: Sendable {
    public var parse: @Sendable (String) -> [Block]

    public init(parse: @escaping @Sendable (String) -> [Block]) {
        self.parse = parse
    }
}

public extension MarkdownParser {
    static let live = MarkdownParser { markdown in
        let document = Document(parsing: markdown)
        var visitor = BlockVisitor()
        
        return visitor.visit(document)
    }
}
