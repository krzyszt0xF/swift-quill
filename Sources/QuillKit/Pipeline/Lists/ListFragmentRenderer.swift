import QuillCore
import UIKit

enum ListFragmentRenderer {
    static func makeOrderedListRenderFragments(
        itemOwnerBlockID: BlockIdentity,
        items: [Block.ListItem],
        nestingContext: NestingContext,
        renderContext: RenderContext,
        startIndex: UInt
    ) -> [RenderFragment] {
        let bodyFont = BlockStyleFactory.bodyFont()

        return items.enumerated().flatMap { index, item in
            let marker = ListMarkerFactory.makeOrderedListMarker(
                checkbox: item.checkbox,
                itemIndex: index,
                startIndex: startIndex
            )
            return makeListItemRenderFragments(
                bodyFont: bodyFont,
                item: item,
                marker: marker,
                ownerBlockID: itemOwnerBlockID,
                nestingContext: nestingContext,
                renderContext: renderContext
            )
        }
    }

    static func makeUnorderedListRenderFragments(
        itemOwnerBlockID: BlockIdentity,
        items: [Block.ListItem],
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> [RenderFragment] {
        let bodyFont = BlockStyleFactory.bodyFont()
        let bullet = ListMarkerFactory.makeUnorderedBullet(for: nestingContext.listLevel)

        return items.flatMap { item in
            let marker = ListMarkerFactory.makeUnorderedListMarker(
                bullet: bullet,
                checkbox: item.checkbox
            )
            return makeListItemRenderFragments(
                bodyFont: bodyFont,
                item: item,
                marker: marker,
                ownerBlockID: itemOwnerBlockID,
                nestingContext: nestingContext,
                renderContext: renderContext
            )
        }
    }
}

private extension ListFragmentRenderer {
    struct ListItemChildRenderUnit {
        let canCarryMarker: Bool
        let fragments: [RenderFragment]
    }

    static func applyAlignedListTextRowStyle(
        bodyFont: UIFont,
        marker: String,
        nestingContext: NestingContext,
        to fragment: RenderFragment
    ) -> RenderFragment {
        let style = BlockStyleFactory.makeAlignedListItemParagraphStyle(
            bodyFont: bodyFont,
            marker: marker,
            nestingContext: nestingContext
        )
        let attributedString = NSMutableAttributedString(attributedString: fragment.attributedString)
        attributedString.addAttribute(
            .paragraphStyle,
            value: style,
            range: NSRange(location: 0, length: attributedString.length)
        )

        return RenderFragment(
            attributedString: AttributedStringAttributeFormatter.makeAttributedStringWithBlockquoteDepth(
                attributedString,
                nestingContext: nestingContext
            ),
            contentBlockID: fragment.contentBlockID,
            ownerBlockID: fragment.ownerBlockID,
            presentationRole: fragment.presentationRole
        )
    }

    static func applyListMarker(
        bodyFont: UIFont,
        marker: String,
        nestingContext: NestingContext,
        to fragment: RenderFragment
    ) -> RenderFragment {
        let style = BlockStyleFactory.makeListItemMarkerParagraphStyle(
            bodyFont: bodyFont,
            marker: marker,
            nestingContext: nestingContext
        )
        let markerString = NSMutableAttributedString(string: marker, attributes: [
            .font: bodyFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: style,
            .structuralMarker: true,
        ])
        markerString.append(fragment.attributedString)
        markerString.addAttribute(
            .paragraphStyle,
            value: style,
            range: NSRange(location: 0, length: markerString.length)
        )

        return RenderFragment(
            attributedString: AttributedStringAttributeFormatter.makeAttributedStringWithBlockquoteDepth(
                markerString,
                nestingContext: nestingContext
            ),
            contentBlockID: fragment.contentBlockID,
            ownerBlockID: fragment.ownerBlockID,
            presentationRole: fragment.presentationRole
        )
    }

    static func makeListItemChildRenderUnit(
        bodyFont: UIFont,
        child: BlockNode,
        ownerBlockID: BlockIdentity,
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> ListItemChildRenderUnit {
        switch child.block {
        case let .heading(level, content):
            return ListItemChildRenderUnit(
                canCarryMarker: true,
                fragments: [makeTextListRenderFragment(
                    attributedString: NSMutableAttributedString(
                        attributedString: BlockAttributedStringRenderer.makeHeadingAttributedString(
                            content: content,
                            level: level,
                            nestingContext: nestingContext
                        )
                    ),
                    contentBlockID: child.id,
                    nestingContext: nestingContext,
                    ownerBlockID: ownerBlockID,
                    presentationRole: .indentedListText
                )]
            )
        case let .htmlBlock(rawHTML):
            return ListItemChildRenderUnit(
                canCarryMarker: true,
                fragments: [makeTextListRenderFragment(
                    attributedString: NSMutableAttributedString(
                        attributedString: BlockAttributedStringRenderer.makeHTMLBlockAttributedString(
                            nestingContext: nestingContext,
                            rawHTML: rawHTML
                        )
                    ),
                    contentBlockID: child.id,
                    nestingContext: nestingContext,
                    ownerBlockID: ownerBlockID,
                    presentationRole: .indentedListText
                )]
            )
        case let .paragraph(content):
            return ListItemChildRenderUnit(
                canCarryMarker: true,
                fragments: [makeTextListRenderFragment(
                    attributedString: NSMutableAttributedString(
                        attributedString: InlineContentRenderer.attributedString(for: content, baseFont: bodyFont)
                    ),
                    contentBlockID: child.id,
                    nestingContext: nestingContext,
                    ownerBlockID: ownerBlockID,
                    presentationRole: .indentedListText
                )]
            )
        default:
            return ListItemChildRenderUnit(
                canCarryMarker: false,
                fragments: RenderFragmentBuilder.makeRenderFragments(
                    for: child,
                    ownerBlockID: ownerBlockID,
                    nestingContext: nestingContext,
                    renderContext: renderContext
                )
            )
        }
    }

    static func makeListItemRenderFragments(
        bodyFont: UIFont,
        item: Block.ListItem,
        marker: String,
        ownerBlockID: BlockIdentity,
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> [RenderFragment] {
        let childContext = nestingContext.incrementingListLevel()
        let childUnits = item.children.map { child in
            makeListItemChildRenderUnit(
                bodyFont: bodyFont,
                child: child,
                ownerBlockID: ownerBlockID,
                nestingContext: childContext,
                renderContext: renderContext
            )
        }
        let markerCarrierIndex = childUnits.firstIndex(where: \.canCarryMarker)

        var fragments: [RenderFragment] = []
        if markerCarrierIndex == nil {
            fragments.append(makeStandaloneListMarkerFragment(
                bodyFont: bodyFont,
                marker: marker,
                nestingContext: nestingContext,
                ownerBlockID: ownerBlockID
            ))
        }

        for (index, unit) in childUnits.enumerated() {
            if index == markerCarrierIndex {
                fragments.append(applyListMarker(
                    bodyFont: bodyFont,
                    marker: marker,
                    nestingContext: nestingContext,
                    to: unit.fragments[0]
                ))
                fragments.append(contentsOf: unit.fragments.dropFirst())
                continue
            }

            if unit.canCarryMarker {
                if let firstFragment = unit.fragments.first {
                    fragments.append(applyAlignedListTextRowStyle(
                        bodyFont: bodyFont,
                        marker: marker,
                        nestingContext: nestingContext,
                        to: firstFragment
                    ))
                }
                fragments.append(contentsOf: unit.fragments.dropFirst())
                continue
            }

            if markerCarrierIndex == nil,
               fragments.last?.presentationRole == .standaloneListMarker,
               let firstFragment = unit.fragments.first,
               firstFragment.presentationRole == .fullWidthEmbeddedBlock {
                fragments.append(
                    makeRenderFragmentWithAdjustedParagraphSpacing(
                        firstFragment,
                        paragraphSpacingBefore: 0
                    )
                )
                fragments.append(contentsOf: unit.fragments.dropFirst())
                continue
            }

            fragments.append(contentsOf: unit.fragments)
        }

        return fragments
    }

    static func makeRenderFragmentWithAdjustedParagraphSpacing(
        _ fragment: RenderFragment,
        paragraphSpacingBefore: CGFloat
    ) -> RenderFragment {
        let attributedString = NSMutableAttributedString(attributedString: fragment.attributedString)
        let range = NSRange(location: 0, length: attributedString.length)
        let paragraphStyle = (attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)?
            .mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacingBefore = paragraphSpacingBefore
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)

        return RenderFragment(
            attributedString: attributedString,
            contentBlockID: fragment.contentBlockID,
            ownerBlockID: fragment.ownerBlockID,
            presentationRole: fragment.presentationRole
        )
    }

    static func makeStandaloneListMarkerFragment(
        bodyFont: UIFont,
        marker: String,
        nestingContext: NestingContext,
        ownerBlockID: BlockIdentity
    ) -> RenderFragment {
        let style = BlockStyleFactory.makeListItemMarkerParagraphStyle(
            bodyFont: bodyFont,
            marker: marker,
            nestingContext: nestingContext
        )
        let attributedString = NSMutableAttributedString(string: marker, attributes: [
            .font: bodyFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: style,
            .structuralMarker: true,
        ])

        return RenderFragment(
            attributedString: AttributedStringAttributeFormatter.makeAttributedStringWithBlockquoteDepth(
                attributedString,
                nestingContext: nestingContext
            ),
            contentBlockID: ownerBlockID,
            ownerBlockID: ownerBlockID,
            presentationRole: .standaloneListMarker
        )
    }

    static func makeTextListRenderFragment(
        attributedString: NSMutableAttributedString,
        contentBlockID: BlockIdentity,
        nestingContext: NestingContext,
        ownerBlockID: BlockIdentity,
        presentationRole: RenderFragment.PresentationRole
    ) -> RenderFragment {
        RenderFragment(
            attributedString: AttributedStringAttributeFormatter.makeAttributedStringWithBlockquoteDepth(
                attributedString,
                nestingContext: nestingContext
            ),
            contentBlockID: contentBlockID,
            ownerBlockID: ownerBlockID,
            presentationRole: presentationRole
        )
    }
}
