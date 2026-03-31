import QuillCore
import UIKit

enum ListPlainRenderer {
    static func buildOrderedListAttributedString(
        items: [Block.ListItem],
        nestingContext: NestingContext,
        renderContext: RenderContext,
        startIndex: UInt
    ) -> NSAttributedString {
        buildListAttributedString(
            items: items,
            nestingContext: nestingContext,
            renderContext: renderContext
        ) { index, item in
            ListMarkerFactory.makeOrderedListMarker(
                checkbox: item.checkbox,
                itemIndex: index,
                startIndex: startIndex
            )
        }
    }

    static func buildUnorderedListAttributedString(
        items: [Block.ListItem],
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> NSAttributedString {
        let bullet = ListMarkerFactory.makeUnorderedBullet(for: nestingContext.listLevel)

        return buildListAttributedString(
            items: items,
            nestingContext: nestingContext,
            renderContext: renderContext
        ) { _, item in
            ListMarkerFactory.makeUnorderedListMarker(
                bullet: bullet,
                checkbox: item.checkbox
            )
        }
    }
}

private extension ListPlainRenderer {
    static func buildListAttributedString(
        items: [Block.ListItem],
        nestingContext: NestingContext,
        renderContext: RenderContext,
        makeMarker: (Int, Block.ListItem) -> String
    ) -> NSAttributedString {
        let bodyFont = BlockStyleFactory.bodyFont()
        let result = NSMutableAttributedString()

        for (index, item) in items.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n"))
            }
            result.append(buildListItemAttributedString(
                bodyFont: bodyFont,
                item: item,
                marker: makeMarker(index, item),
                nestingContext: nestingContext,
                renderContext: renderContext
            ))
        }

        return result
    }

    static func buildListItemAttributedString(
        bodyFont: UIFont,
        item: Block.ListItem,
        marker: String,
        nestingContext: NestingContext,
        renderContext: RenderContext
    ) -> NSAttributedString {
        let style = BlockStyleFactory.makeListItemMarkerParagraphStyle(
            bodyFont: bodyFont,
            marker: marker,
            nestingContext: nestingContext
        )
        let result = NSMutableAttributedString(string: marker, attributes: [
            .font: bodyFont,
            .foregroundColor: UIColor.label,
            .paragraphStyle: style,
            .structuralMarker: true,
        ])
        let childContext = nestingContext.incrementingListLevel()

        for (childIndex, child) in item.children.enumerated() {
            if childIndex == 0, case let .paragraph(content) = child.block {
                result.append(InlineContentRenderer.attributedString(for: content, baseFont: bodyFont))
                result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
                continue
            }

            result.append(NSAttributedString(string: "\n"))
            result.append(BlockAttributedStringRenderer.makeAttributedString(
                for: child.block,
                nestingContext: childContext,
                renderContext: renderContext
            ))
        }

        return result
    }
}
