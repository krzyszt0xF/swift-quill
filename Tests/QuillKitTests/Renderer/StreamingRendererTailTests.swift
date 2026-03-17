@testable import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("StreamingBlockRenderer Tail")
struct StreamingRendererTailTests {
    @Test("Clear tail removes the tail view")
    func clearTailRemovesTailView() {
        let renderer = StreamingBlockRenderer()

        let frozenBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
        ]
        renderer.update(blocks: frozenBlocks, frozenCount: 2)

        renderer.updateTail(block: .paragraph(content: [.text("tail")]))
        #expect(renderer.renderedBlockViews.count == 3)

        renderer.clearTail()
        #expect(renderer.renderedBlockViews.count == 2)
    }

    @Test("Frozen prefix identity through full pipeline")
    func frozenPrefixRemainsStableAcrossTailChanges() {
        let renderer = StreamingBlockRenderer()

        let initialBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
        ]
        renderer.update(blocks: initialBlocks, frozenCount: 3)

        let firstFrozenView = renderer.renderedBlockViews[0]
        let secondFrozenView = renderer.renderedBlockViews[1]
        let thirdFrozenView = renderer.renderedBlockViews[2]

        let updatedBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: nil, code: "New tail 1\n"),
            .paragraph(content: [.text("New tail 2")]),
        ]
        renderer.update(blocks: updatedBlocks, frozenCount: 3)

        #expect(renderer.renderedBlockViews[0] === firstFrozenView)
        #expect(renderer.renderedBlockViews[1] === secondFrozenView)
        #expect(renderer.renderedBlockViews[2] === thirdFrozenView)
    }

    @Test("Tail promotion keeps the same view instance")
    func tailPromotionKeepsViewIdentity() throws {
        let renderer = StreamingBlockRenderer()

        let tailBlock: Block = .paragraph(content: [.text("mutable frontier")])
        renderer.updateTail(block: tailBlock)
        let tailView = try #require(renderer.renderedBlockViews.last)

        let promotedView = renderer.promoteTailIfMatching(tailBlock)

        #expect(promotedView === tailView)
        #expect(renderer.renderedBlockViews.count == 1)
        #expect(renderer.renderedBlockViews[0] === tailView)
    }

    @Test("Tail update adds view after frozen content")
    func tailUpdateAddsViewAfterFrozenContent() {
        let renderer = StreamingBlockRenderer()

        let frozenBlocks: [Block] = [
            .paragraph(content: [.text("F1")]),
            .codeBlock(language: nil, code: "F2\n"),
            .paragraph(content: [.text("F3")]),
            .codeBlock(language: "swift", code: "F4\n"),
            .paragraph(content: [.text("F5")]),
        ]
        renderer.update(blocks: frozenBlocks, frozenCount: 5)

        let renderedViewCountBeforeTail = renderer.renderedBlockViews.count

        let tailBlock: Block = .paragraph(content: [.text("tail content")])
        renderer.updateTail(block: tailBlock)

        #expect(renderer.renderedBlockViews.count == renderedViewCountBeforeTail + 1)
        #expect(renderer.renderedBlockViews.last is TextFlowView)
    }

    // MARK: - Styled Tail Promotion Tests

    @Test("Styled paragraph tail promotes to frozen")
    func styledParagraphTailPromotes() {
        let renderer = StreamingBlockRenderer()

        let tailBlock: Block = .paragraph(content: [.text("Hello "), .strong([.text("world")])])
        renderer.updateTail(block: tailBlock)
        #expect(renderer.renderedBlockViews.count == 1)

        let frozenBlock: Block = .paragraph(content: [.text("Hello "), .strong([.text("world")])])
        let promoted = renderer.promoteTailIfMatching(frozenBlock)
        #expect(promoted != nil)
    }

    @Test("Styled heading tail promotes to frozen")
    func styledHeadingTailPromotes() {
        let renderer = StreamingBlockRenderer()

        let tailBlock: Block = .heading(level: 2, content: [.text("My "), .emphasis([.text("heading")])])
        renderer.updateTail(block: tailBlock)
        #expect(renderer.renderedBlockViews.count == 1)

        let frozenBlock: Block = .heading(level: 2, content: [.text("My "), .emphasis([.text("heading")])])
        let promoted = renderer.promoteTailIfMatching(frozenBlock)
        #expect(promoted != nil)
    }

    @Test("Styled list tail promotes and has structural markers")
    func styledListTailPromotes() {
        let renderer = StreamingBlockRenderer()

        let tailBlock: Block = .unorderedList(items: [
            Block.ListItem(children: [.paragraph(content: [.strong([.text("bold item")])])])
        ])
        renderer.updateTail(block: tailBlock)
        #expect(renderer.renderedBlockViews.count == 1)

        let frozenBlock: Block = .unorderedList(items: [
            Block.ListItem(children: [.paragraph(content: [.strong([.text("bold item")])])])
        ])
        let promoted = renderer.promoteTailIfMatching(frozenBlock)
        #expect(promoted != nil)
    }

    @Test("Styled tail promotion preserves view instance")
    func styledTailPromotionPreservesViewInstance() throws {
        let renderer = StreamingBlockRenderer()

        let tailBlock: Block = .paragraph(content: [.text("Hello "), .strong([.text("world")])])
        renderer.updateTail(block: tailBlock)
        let tailView = try #require(renderer.renderedBlockViews.last)

        let frozenBlock: Block = .paragraph(content: [.text("Hello "), .strong([.text("world")])])
        let promoted = renderer.promoteTailIfMatching(frozenBlock)

        #expect(promoted === tailView)
        #expect(renderer.renderedBlockViews.count == 1)
        #expect(renderer.renderedBlockViews[0] === tailView)
    }

    // MARK: - Non-flow Block Baseline Tests

    @Test("Code block tail shows language and growing content")
    func codeBlockTailLanguageAndContent() throws {
        let renderer = StreamingBlockRenderer()
        renderer.tailConfiguration = .default

        let tailBlock: Block = .codeBlock(language: "swift", code: "let x = 1\n")
        renderer.updateTail(block: tailBlock)

        let codeView = try #require(renderer.renderedBlockViews.last as? CodeBlockView)
        #expect(codeView.currentLanguage == "swift")

        let updatedBlock: Block = .codeBlock(language: "swift", code: "let x = 1\nlet y = 2\n")
        renderer.updateTail(block: updatedBlock)

        let updatedView = try #require(renderer.renderedBlockViews.last as? CodeBlockView)
        #expect(updatedView === codeView)
    }

    @Test("Table tail shows PlaceholderBlockView with row count")
    func tableTailPlaceholder() throws {
        let renderer = StreamingBlockRenderer()

        let header = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Name")]),
            Block.TableCell(content: [.text("Age")]),
        ])
        let rows = [
            Block.TableRow(cells: [
                Block.TableCell(content: [.text("Alice")]),
                Block.TableCell(content: [.text("30")]),
            ]),
        ]
        let tailBlock: Block = .table(columnAlignments: [nil, nil], header: header, rows: rows)
        renderer.updateTail(block: tailBlock)

        try #require(renderer.renderedBlockViews.last is PlaceholderBlockView)
    }

    @Test("Image RenderNode produces PlaceholderBlockView")
    func imageRenderNodePlaceholder() {
        let view = RenderNodeViewFactory.view(for: .image(source: "https://example.com/img.png", title: "Photo"))
        #expect(view is PlaceholderBlockView)
    }

    @Test("Image inline in paragraph flows through TextFlowView")
    func imageInlineTailFlow() throws {
        let renderer = StreamingBlockRenderer()

        let tailBlock: Block = .paragraph(content: [.image(source: "https://example.com/img.png", title: "Photo", alt: [.text("A photo")])])
        renderer.updateTail(block: tailBlock)

        try #require(renderer.renderedBlockViews.last is TextFlowView)
    }
}
