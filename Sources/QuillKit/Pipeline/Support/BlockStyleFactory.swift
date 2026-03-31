import UIKit

enum BlockStyleFactory {
    static func bodyFont() -> UIFont {
        UIFont.systemFont(ofSize: 16)
    }

    static func headingFont(level: Int) -> UIFont {
        switch level {
        case 1:
            return .systemFont(ofSize: 28, weight: .bold)
        case 2:
            return .systemFont(ofSize: 24, weight: .bold)
        case 3:
            return .systemFont(ofSize: 20, weight: .semibold)
        case 4:
            return .systemFont(ofSize: 18, weight: .semibold)
        case 5:
            return .systemFont(ofSize: 16, weight: .medium)
        case 6:
            return .systemFont(ofSize: 14, weight: .medium)
        default:
            return .systemFont(ofSize: 16)
        }
    }

    static func makeAlignedListItemParagraphStyle(
        bodyFont: UIFont,
        marker: String,
        nestingContext: NestingContext
    ) -> NSMutableParagraphStyle {
        let style = makeListParagraphStyle(
            bodyFont: bodyFont,
            level: nestingContext.listLevel,
            marker: marker
        )
        style.firstLineHeadIndent = style.headIndent
        applyBlockquoteIndent(to: style, nestingContext: nestingContext)
        return style
    }

    static func makeListItemMarkerParagraphStyle(
        bodyFont: UIFont,
        marker: String,
        nestingContext: NestingContext
    ) -> NSMutableParagraphStyle {
        let style = makeListParagraphStyle(
            bodyFont: bodyFont,
            level: nestingContext.listLevel,
            marker: marker
        )
        applyBlockquoteIndent(to: style, nestingContext: nestingContext)
        return style
    }

    static func makeListParagraphStyle(
        bodyFont: UIFont,
        level: Int,
        marker: String
    ) -> NSMutableParagraphStyle {
        let baseIndent = CGFloat(level) * 24
        let markerWidth = (marker as NSString).size(withAttributes: [.font: bodyFont]).width
        let indent = baseIndent + markerWidth

        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = baseIndent
        style.headIndent = indent
        style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
        style.defaultTabInterval = indent
        style.paragraphSpacingBefore = 4
        return style
    }

    static func makeParagraphStyle(
        nestingContext: NestingContext,
        paragraphSpacingBefore: CGFloat
    ) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = paragraphSpacingBefore
        applyBlockquoteIndent(to: style, nestingContext: nestingContext)
        return style
    }

    static func makePresentationRoleParagraphStyle(
        nestingContext: NestingContext,
        paragraphSpacingBefore: CGFloat,
        presentationRole: RenderFragment.PresentationRole
    ) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = paragraphSpacingBefore
        applyPresentationRoleIndent(
            to: style,
            nestingContext: nestingContext,
            presentationRole: presentationRole
        )
        return style
    }

    static func makeThematicBreakParagraphStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacingBefore = 8
        return style
    }

    static func monospaceFont() -> UIFont {
        UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    }
}

private extension BlockStyleFactory {
    static func applyBlockquoteIndent(
        to style: NSMutableParagraphStyle,
        nestingContext: NestingContext
    ) {
        guard nestingContext.blockquoteDepth > 0 else { return }

        let indent = CGFloat(nestingContext.blockquoteDepth) * BlockquoteStyle.levelSpacing
        style.headIndent += indent
        style.firstLineHeadIndent += indent
    }

    static func applyNestedBlockIndent(
        to style: NSMutableParagraphStyle,
        nestingContext: NestingContext
    ) {
        applyBlockquoteIndent(to: style, nestingContext: nestingContext)

        guard nestingContext.listLevel > 0 else { return }

        let indent = CGFloat(nestingContext.listLevel) * 24 + 12
        style.headIndent += indent
        style.firstLineHeadIndent += indent
    }

    static func applyPresentationRoleIndent(
        to style: NSMutableParagraphStyle,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole
    ) {
        switch presentationRole {
        case .fullWidthEmbeddedBlock, .regularBlock, .standaloneListMarker:
            applyBlockquoteIndent(to: style, nestingContext: nestingContext)
        case .indentedListBlock, .indentedListText:
            applyNestedBlockIndent(to: style, nestingContext: nestingContext)
        }
    }
}
