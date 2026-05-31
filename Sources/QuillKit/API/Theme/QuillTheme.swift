import UIKit

// @unchecked Sendable: composed of token groups that hold non-Sendable UIKit types (UIFont, UIColor);
// the theme value is treated as an immutable snapshot once constructed and is never mutated across actor boundaries.
/// Product-facing visual theme for Quill rendering, treated as an immutable sendable snapshot.
public struct QuillTheme: @unchecked Sendable, Equatable {
    public var blockquote: Blockquote
    public var body: Body
    public var codeBlock: CodeBlock
    public var heading: Heading
    public var image: Image
    public var inline: Inline
    public var link: Link
    public var list: List
    public var spacing: Spacing
    public var table: Table
    public var thematicBreak: ThematicBreak

    public init(
        blockquote: Blockquote,
        body: Body,
        codeBlock: CodeBlock,
        heading: Heading,
        image: Image,
        inline: Inline,
        link: Link,
        list: List,
        spacing: Spacing,
        table: Table,
        thematicBreak: ThematicBreak
    ) {
        self.blockquote = blockquote
        self.body = body
        self.codeBlock = codeBlock
        self.heading = heading
        self.image = image
        self.inline = inline
        self.link = link
        self.list = list
        self.spacing = spacing
        self.table = table
        self.thematicBreak = thematicBreak
    }

    public init() {
        self = .default
    }
}
