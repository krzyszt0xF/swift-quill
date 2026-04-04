import QuillCore
import QuillCoreTestSupport
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@Suite("AttributedStringBuilder Render Fragments", .tags(.rendering))
struct AttributedStringBuilderFragmentTests {
    @Test("Paragraph-only document produces one fragment per block")
    func documentParagraphOnly() {
        let blocks: [Block] = [
            .paragraph(content: [.text("Hello")]),
            .paragraph(content: [.text("World")]),
        ]
        let fragments = AttributedStringBuilder.buildRenderFragments(from: blocks.makeNodes(), frozenCount: blocks.count)

        #expect(fragments.count == 2)
        #expect(fragments[0].attributedString.string.contains("Hello"))
        #expect(fragments[1].attributedString.string.contains("World"))
    }

    @Test("Closed code block produces CodeBlockAttachment fragment")
    func documentClosedCodeBlock() {
        let blocks: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
            .paragraph(content: [.text("After")]),
        ]
        let fragments = AttributedStringBuilder.buildRenderFragments(from: blocks.makeNodes(), frozenCount: blocks.count)

        #expect(fragments.count == 3)

        var foundCodeBlockAttachment = false
        fragments[1].attributedString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: fragments[1].attributedString.length)
        ) { value, _, _ in
            if value is CodeBlockAttachment { foundCodeBlockAttachment = true }
        }
        #expect(foundCodeBlockAttachment)
    }

    @Test("Open code fence renders as plain monospace text")
    func documentOpenCodeFence() {
        let blocks: [Block] = [
            .paragraph(content: [.text("Before")]),
            .codeBlock(language: "swift", code: "let x = 1\n"),
        ]
        let fragments = AttributedStringBuilder.buildRenderFragments(from: blocks.makeNodes(), frozenCount: 1)

        #expect(fragments.count == 2)
        #expect(fragments[1].attributedString.string.contains("let x = 1"))
        #expect(fragments[1].attributedString.string.hasSuffix("\n"))

        var foundCodeBlockAttachment = false
        fragments[1].attributedString.enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: fragments[1].attributedString.length)
        ) { value, _, _ in
            if value is CodeBlockAttachment { foundCodeBlockAttachment = true }
        }
        #expect(foundCodeBlockAttachment == false)

        let resultFont = attributedStringBuilderFont(in: fragments[1].attributedString)
        #expect(resultFont?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true)
    }

    @Test("Unfrozen table fallback renders visible plain text with pipe separators")
    func documentUnfrozenTableFallback() {
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
        let blocks: [Block] = [
            .table(columnAlignments: [nil, nil], header: header, rows: rows),
        ]
        let fragments = AttributedStringBuilder.buildRenderFragments(from: blocks.makeNodes(), frozenCount: 0)

        #expect(fragments.count == 1)

        let text = fragments[0].attributedString.string
        #expect(text.contains("Name"))
        #expect(text.contains("Age"))
        #expect(text.contains("Alice"))
        #expect(text.contains("30"))
        #expect(text.contains("|"))
    }

    @Test("Blockquote depth propagates in render fragments")
    func documentBlockquoteDepth() {
        let blocks: [Block] = [
            Block.makeBlockquote(Block.makeBlockquote(.paragraph(content: [.text("deep")]))),
        ]
        let fragments = AttributedStringBuilder.buildRenderFragments(from: blocks.makeNodes(), frozenCount: blocks.count)

        #expect(fragments.count == 1)
        #expect(fragments[0].blockquoteDepth == 2)
    }

    @Test("Blockquote nested list fragment keeps owner identity and list text role")
    func blockquoteNestedListFragmentMetadata() {
        let paragraphID = BlockIdentity(rawValue: 21)
        let blockquoteID = BlockIdentity(rawValue: 23)
        let nodes = [
            BlockNode(
                block: .blockquote(children: [
                    BlockNode(
                        block: .orderedList(startIndex: 1, items: [
                            Block.ListItem(children: [
                                BlockNode(
                                    block: .paragraph(content: [.text("Nested")]),
                                    id: paragraphID
                                ),
                            ]),
                        ]),
                        id: BlockIdentity(rawValue: 22)
                    ),
                ]),
                id: blockquoteID
            ),
        ]

        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: nodes.count)

        #expect(fragments.count == 1)
        #expect(fragments[0].presentationRole == .indentedListText)
        #expect(fragments[0].blockquoteDepth == 1)
        #expect(fragments[0].ownerBlockID == blockquoteID)
        #expect(fragments[0].contentBlockID == paragraphID)
    }

    @Test("Empty input produces no fragments")
    func documentEmptyInput() {
        let fragments = AttributedStringBuilder.buildRenderFragments(from: [], frozenCount: 0)
        #expect(fragments.isEmpty)
    }

    @Test("buildDocument concatenates fragments with newline separators")
    func buildDocumentConcatenation() {
        let blocks: [Block] = [
            .paragraph(content: [.text("one")]),
            .paragraph(content: [.text("two")]),
        ]
        let fragments = AttributedStringBuilder.buildRenderFragments(from: blocks.makeNodes(), frozenCount: blocks.count)
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        #expect(document.string.contains("one"))
        #expect(document.string.contains("two"))
        #expect(document.string.contains("\n"))
    }

    @Test("buildDocument stamps owner and content block IDs on each fragment range")
    func buildDocumentBlockIDAttributes() {
        let id1 = BlockIdentity(rawValue: 10)
        let id2 = BlockIdentity(rawValue: 11)
        let nodes = [
            BlockNode(block: .paragraph(content: [.text("alpha")]), id: id1),
            BlockNode(block: .paragraph(content: [.text("beta")]), id: id2),
        ]
        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: nodes.count)
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        let alphaRange = (document.string as NSString).range(of: "alpha")
        let betaRange = (document.string as NSString).range(of: "beta")

        let alphaContentBlockID = document.attribute(.contentBlockID, at: alphaRange.location, effectiveRange: nil) as? BlockIdentity
        let alphaOwnerBlockID = document.attribute(.ownerBlockID, at: alphaRange.location, effectiveRange: nil) as? BlockIdentity
        let betaContentBlockID = document.attribute(.contentBlockID, at: betaRange.location, effectiveRange: nil) as? BlockIdentity
        let betaOwnerBlockID = document.attribute(.ownerBlockID, at: betaRange.location, effectiveRange: nil) as? BlockIdentity

        #expect(alphaContentBlockID == id1)
        #expect(alphaOwnerBlockID == id1)
        #expect(betaContentBlockID == id2)
        #expect(betaOwnerBlockID == id2)
    }

    @Test("buildDocument keeps separator unstamped and attachment range stamped")
    func buildDocumentSeparatorAndAttachmentAttributes() throws {
        let textID = BlockIdentity(rawValue: 10)
        let attachmentID = BlockIdentity(rawValue: 11)
        let attachment = NSTextAttachment()
        let fragments = [
            RenderFragment(
                attributedString: NSAttributedString(string: "alpha"),
                blockquoteDepth: 0,
                contentBlockID: textID,
                ownerBlockID: textID,
                presentationRole: .regularBlock
            ),
            RenderFragment(
                attributedString: NSAttributedString(attachment: attachment),
                blockquoteDepth: 2,
                contentBlockID: attachmentID,
                ownerBlockID: attachmentID,
                presentationRole: .fullWidthEmbeddedBlock
            ),
        ]

        let document = AttributedStringBuilder.buildDocument(from: fragments)
        let separatorIndex = (document.string as NSString).range(of: "\n").location
        let attachmentIndex = try #require(document.firstAttachmentIndex)

        let separatorOwnerID = document.attribute(
            .ownerBlockID,
            at: separatorIndex,
            effectiveRange: nil
        ) as? BlockIdentity
        let separatorContentID = document.attribute(
            .contentBlockID,
            at: separatorIndex,
            effectiveRange: nil
        ) as? BlockIdentity
        let attachmentOwnerID = document.attribute(
            .ownerBlockID,
            at: attachmentIndex,
            effectiveRange: nil
        ) as? BlockIdentity
        let attachmentContentID = document.attribute(
            .contentBlockID,
            at: attachmentIndex,
            effectiveRange: nil
        ) as? BlockIdentity
        let separatorBlockquoteDepth = document.attribute(
            .blockquoteDepth,
            at: separatorIndex,
            effectiveRange: nil
        ) as? Int
        let attachmentBlockquoteDepth = document.attribute(
            .blockquoteDepth,
            at: attachmentIndex,
            effectiveRange: nil
        ) as? Int

        #expect(separatorOwnerID == nil)
        #expect(separatorContentID == nil)
        #expect(separatorBlockquoteDepth == nil)
        #expect(attachmentOwnerID == attachmentID)
        #expect(attachmentContentID == attachmentID)
        #expect(attachmentBlockquoteDepth == 2)
    }

    @Test("Each simple top-level fragment keeps matching owner and content IDs")
    func documentFragmentMatchingIDs() {
        let blocks: [Block] = [
            .paragraph(content: [.text("a")]),
            .paragraph(content: [.text("b")]),
            .codeBlock(language: nil, code: "c"),
        ]
        let fragments = AttributedStringBuilder.buildRenderFragments(from: blocks.makeNodes(), frozenCount: blocks.count)
        #expect(fragments.allSatisfy { $0.ownerBlockID == $0.contentBlockID })
    }

    @Test("Mixed document preserves paragraph-style spacing")
    func documentParagraphStyleSpacing() {
        let blocks: [Block] = [
            .heading(level: 1, content: [.text("Title")]),
            .paragraph(content: [.text("Body")]),
        ]
        let fragments = AttributedStringBuilder.buildRenderFragments(from: blocks.makeNodes(), frozenCount: blocks.count)
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        let titleRange = (document.string as NSString).range(of: "Title")
        let bodyRange = (document.string as NSString).range(of: "Body")

        let titleStyle = document.attribute(.paragraphStyle, at: titleRange.location, effectiveRange: nil) as? NSParagraphStyle
        let bodyStyle = document.attribute(.paragraphStyle, at: bodyRange.location, effectiveRange: nil) as? NSParagraphStyle

        #expect(titleStyle?.paragraphSpacingBefore ?? 0 > 0)
        #expect(bodyStyle?.paragraphSpacingBefore ?? 0 > 0)
    }

    @Test("Unfrozen table fallback renders in current document pipeline")
    func tableFallbackInDocumentPipeline() {
        let header = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Col")]),
        ])
        let table = Block.table(columnAlignments: [nil], header: header, rows: [])
        let result = makePipelineDocument(table, frozenCount: 0)
        #expect(result.string.contains("Col"))
        #expect(result.string.contains("|"))
    }

    @Test("Frozen table produces attachment fragment")
    func frozenTableFragment() {
        let nodes = [
            Block.table(
                columnAlignments: [.left],
                header: Block.TableRow(cells: [
                    Block.TableCell(content: [.text("Name")]),
                ]),
                rows: [
                    Block.TableRow(cells: [
                        Block.TableCell(content: [.text("Quill")]),
                    ]),
                ]
            ),
        ].makeNodes()

        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: 1)
        let attachment = fragments.first?.attributedString.attribute(.attachment, at: 0, effectiveRange: nil)

        #expect(fragments.count == 1)
        #expect(attachment is TableAttachment)
    }

    @Test("Unfrozen table produces fallback text fragment")
    func unfrozenTableFragment() {
        let nodes = [
            Block.table(
                columnAlignments: [.left],
                header: Block.TableRow(cells: [
                    Block.TableCell(content: [.text("Name")]),
                ]),
                rows: [
                    Block.TableRow(cells: [
                        Block.TableCell(content: [.text("Quill")]),
                    ]),
                ]
            ),
        ].makeNodes()

        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: 0)
        let attachment = fragments.first?.attributedString.attribute(.attachment, at: 0, effectiveRange: nil)

        #expect(fragments.first?.attributedString.string.contains("|") == true)
        #expect(attachment == nil)
    }

    @Test("Frozen ordered list renders nested code block attachment")
    func frozenOrderedListNestedCodeBlockAttachment() {
        let nodes = [
            Block.orderedList(startIndex: 1, items: [
                Block.ListItem(blocks:
                    .paragraph(content: [.text("Code")]),
                    .codeBlock(language: "swift", code: "print(\"Hello\")\n")
                ),
            ]),
        ].makeNodes()

        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: 1)

        #expect(fragments.count == 2)
        #expect(fragments[0].presentationRole == .indentedListText)
        #expect(fragments[1].presentationRole == .fullWidthEmbeddedBlock)
        #expect(fragments[1].attributedString.containsAttachment(CodeBlockAttachment.self))
        let style = fragments[1].attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(style?.headIndent == 0)
    }

    @Test("Frozen unordered list renders nested table attachment")
    func frozenUnorderedListNestedTableAttachment() {
        let header = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Name")]),
            Block.TableCell(content: [.text("Value")]),
        ])
        let rows = [
            Block.TableRow(cells: [
                Block.TableCell(content: [.text("Quill")]),
                Block.TableCell(content: [.text("1")]),
            ]),
        ]
        let nodes = [
            Block.unorderedList(items: [
                Block.ListItem(blocks:
                    .paragraph(content: [.text("Table")]),
                    .table(columnAlignments: [.left, .right], header: header, rows: rows)
                ),
            ]),
        ].makeNodes()

        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: 1)

        #expect(fragments.count == 2)
        #expect(fragments[0].presentationRole == .indentedListText)
        #expect(fragments[1].presentationRole == .fullWidthEmbeddedBlock)
        #expect(fragments[1].attributedString.containsAttachment(TableAttachment.self))
        let style = fragments[1].attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(style?.headIndent == 0)
    }

    @Test("Unfrozen unordered list keeps nested table fallback text visible")
    func unfrozenUnorderedListNestedTableFallback() {
        let header = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Name")]),
            Block.TableCell(content: [.text("Value")]),
        ])
        let rows = [
            Block.TableRow(cells: [
                Block.TableCell(content: [.text("Quill")]),
                Block.TableCell(content: [.text("1")]),
            ]),
        ]
        let nodes = [
            Block.unorderedList(items: [
                Block.ListItem(blocks:
                    .paragraph(content: [.text("Table")]),
                    .table(columnAlignments: [.left, .right], header: header, rows: rows)
                ),
            ]),
        ].makeNodes()

        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: 0)

        #expect(fragments.count == 2)
        #expect(fragments[1].attributedString.string.contains("Name"))
        #expect(fragments[1].attributedString.string.contains("Quill"))
        #expect(fragments[1].attributedString.string.contains("|"))
        #expect(fragments[1].attributedString.containsAttachment(TableAttachment.self) == false)
    }

    @Test("List item without text emits standalone marker row above full-width code block")
    func listItemMarkerOnlyRow() {
        let nodes = [
            Block.unorderedList(items: [
                Block.ListItem(blocks:
                    .codeBlock(language: "swift", code: "print(\"Hello\")\n")
                ),
            ]),
        ].makeNodes()

        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: 1)

        #expect(fragments.count == 2)
        #expect(fragments[0].presentationRole == .standaloneListMarker)
        #expect(fragments[1].presentationRole == .fullWidthEmbeddedBlock)

        let style = fragments[1].attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(style?.paragraphSpacingBefore == 0)
    }

    @Test("Task list marker-only row keeps checkbox marker above full-width table")
    func taskListMarkerOnlyRow() {
        let header = Block.TableRow(cells: [
            Block.TableCell(content: [.text("Name")]),
        ])
        let nodes = [
            Block.unorderedList(items: [
                Block.ListItem(
                    checkbox: .checked,
                    blocks: .table(
                        columnAlignments: [.left],
                        header: header,
                        rows: []
                    )
                ),
            ]),
        ].makeNodes()

        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: 1)

        #expect(fragments.count == 2)
        #expect(fragments[0].presentationRole == .standaloneListMarker)
        #expect(fragments[0].attributedString.string.contains("[x]"))
        #expect(fragments[1].presentationRole == .fullWidthEmbeddedBlock)
    }

    @Test("Nested list code block keeps shared owner and child content IDs")
    func nestedListFragmentMetadata() {
        let paragraphID = BlockIdentity(rawValue: 11)
        let codeID = BlockIdentity(rawValue: 12)
        let listID = BlockIdentity(rawValue: 10)
        let nodes = [
            BlockNode(
                block: .orderedList(startIndex: 1, items: [
                    Block.ListItem(children: [
                        BlockNode(block: .paragraph(content: [.text("Intro")]), id: paragraphID),
                        BlockNode(block: .codeBlock(language: "swift", code: "print(\"Hello\")\n"), id: codeID),
                    ]),
                ]),
                id: listID
            ),
        ]

        let fragments = AttributedStringBuilder.buildRenderFragments(from: nodes, frozenCount: 1)
        let document = AttributedStringBuilder.buildDocument(from: fragments)

        let introRange = (document.string as NSString).range(of: "Intro")
        let codeAttachmentIndex = document.firstAttachmentIndex

        let introOwnerID = document.attribute(.ownerBlockID, at: introRange.location, effectiveRange: nil) as? BlockIdentity
        let introContentID = document.attribute(.contentBlockID, at: introRange.location, effectiveRange: nil) as? BlockIdentity
        let codeOwnerID = codeAttachmentIndex.flatMap {
            document.attribute(.ownerBlockID, at: $0, effectiveRange: nil) as? BlockIdentity
        }
        let codeContentID = codeAttachmentIndex.flatMap {
            document.attribute(.contentBlockID, at: $0, effectiveRange: nil) as? BlockIdentity
        }

        #expect(codeAttachmentIndex != nil)
        #expect(introOwnerID == listID)
        #expect(introContentID == paragraphID)
        #expect(codeOwnerID == listID)
        #expect(codeContentID == codeID)
    }
}
