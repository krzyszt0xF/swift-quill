import QuillCore
import UIKit

enum RenderFragmentBuilder {
    static func buildRenderFragments(
        from nodes: [BlockNode],
        frozenCount: Int,
        highlightStore: (any CodeBlockHighlightStore)? = nil
    ) -> [RenderFragment] {
        var fragments: [RenderFragment] = []

        for (index, node) in nodes.enumerated() {
            let renderContext = RenderContext(
                highlightStore: highlightStore,
                rendersAttachments: index < frozenCount
            )
            let nodeFragments = makeRenderFragments(
                for: node,
                ownerBlockID: node.id,
                nestingContext: .root,
                renderContext: renderContext
            )
            fragments.append(contentsOf: nodeFragments.filter { $0.attributedString.length > 0 })
        }

        return fragments
    }

    static func makeRenderFragments(
        for node: BlockNode,
        ownerBlockID: BlockIdentity,
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> [RenderFragment] {
        switch node.block {
        case let .blockquote(children):
            return makeBlockquoteRenderFragments(
                children: children,
                ownerBlockID: ownerBlockID,
                nestingContext: nestingContext,
                renderContext: renderContext
            )
        case let .orderedList(startIndex, items):
            return ListFragmentRenderer.makeOrderedListRenderFragments(
                itemOwnerBlockID: ownerBlockID,
                items: items,
                nestingContext: nestingContext,
                renderContext: renderContext,
                startIndex: startIndex
            )
        case let .unorderedList(items):
            return ListFragmentRenderer.makeUnorderedListRenderFragments(
                itemOwnerBlockID: ownerBlockID,
                items: items,
                nestingContext: nestingContext,
                renderContext: renderContext
            )
        case .codeBlock, .heading, .htmlBlock, .paragraph, .table, .thematicBreak:
            return [makeRenderFragment(
                for: node,
                ownerBlockID: ownerBlockID,
                nestingContext: nestingContext,
                renderContext: renderContext
            )]
        }
    }
}

private extension RenderFragmentBuilder {
    static func makeBlockquoteRenderFragments(
        children: [BlockNode],
        ownerBlockID: BlockIdentity,
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> [RenderFragment] {
        let nestedContext = nestingContext.incrementingBlockquoteDepth()

        return children.flatMap { child in
            makeRenderFragments(
                for: child,
                ownerBlockID: ownerBlockID,
                nestingContext: nestedContext,
                renderContext: renderContext
            )
        }
    }

    static func makePresentationRole(
        for block: Block,
        nestingContext: NestingContext
    ) -> RenderFragment.PresentationRole {
        guard nestingContext.listLevel > 0 else { return .regularBlock }

        if block.isListOutdentedCandidate {
            return .fullWidthEmbeddedBlock
        }
        if block.isListTextCandidate {
            return .indentedListText
        }
        return .indentedListBlock
    }

    // swiftlint:disable:next function_body_length
    static func makeRenderFragment(
        for node: BlockNode,
        ownerBlockID: BlockIdentity,
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> RenderFragment {
        let presentationRole = makePresentationRole(
            for: node.block,
            nestingContext: nestingContext
        )

        let attributedString: NSAttributedString
        switch node.block {
        case let .codeBlock(language, code):
            if renderContext.rendersAttachments {
                attributedString = EmbeddedBlockRenderer.makeCodeBlockAttachmentAttributedString(
                    blockID: node.id,
                    code: code,
                    highlightStore: renderContext.highlightStore,
                    language: language,
                    nestingContext: nestingContext,
                    presentationRole: presentationRole
                )
            } else {
                attributedString = EmbeddedBlockRenderer.makeOpenCodeFenceAttributedString(
                    code: code,
                    nestingContext: nestingContext,
                    presentationRole: presentationRole
                )
            }
        case let .heading(level, content):
            attributedString = TextBlockAttributedStringRenderer.makeHeadingAttributedString(
                content: content,
                level: level,
                nestingContext: nestingContext
            )
        case let .htmlBlock(rawHTML):
            attributedString = TextBlockAttributedStringRenderer.makeHTMLBlockAttributedString(
                nestingContext: nestingContext,
                rawHTML: rawHTML
            )
        case let .paragraph(content):
            attributedString = TextBlockAttributedStringRenderer.makeParagraphAttributedString(
                content: content,
                nestingContext: nestingContext
            )
        case let .table(columnAlignments, header, rows):
            if renderContext.rendersAttachments {
                attributedString = EmbeddedBlockRenderer.makeTableAttachmentAttributedString(
                    blockID: node.id,
                    columnAlignments: columnAlignments,
                    header: header,
                    nestingContext: nestingContext,
                    presentationRole: presentationRole,
                    rows: rows
                )
            } else {
                attributedString = EmbeddedBlockRenderer.makeTableFallbackAttributedString(
                    header: header,
                    rows: rows,
                    nestingContext: nestingContext,
                    presentationRole: presentationRole
                )
            }
        case .thematicBreak:
            attributedString = EmbeddedBlockRenderer.makeThematicBreakAttributedString()
        case .blockquote, .orderedList, .unorderedList:
            preconditionFailure("Lists and blockquotes are rendered through makeRenderFragments")
        }

        return RenderFragment(
            attributedString: AttributedStringAttributeFormatter.makeAttributedStringWithBlockquoteDepth(
                attributedString,
                nestingContext: nestingContext
            ),
            contentBlockID: node.id,
            ownerBlockID: ownerBlockID,
            presentationRole: presentationRole
        )
    }
}

private extension Block {
    var isListOutdentedCandidate: Bool {
        switch self {
        case .codeBlock, .table:
            return true
        default:
            return false
        }
    }

    var isListTextCandidate: Bool {
        switch self {
        case .heading, .htmlBlock, .paragraph:
            return true
        default:
            return false
        }
    }
}
