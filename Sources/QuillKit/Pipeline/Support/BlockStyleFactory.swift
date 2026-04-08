import UIKit

enum BlockStyleFactory {
    static func bodyFont(theme: QuillTheme) -> UIFont {
        theme.body.font
    }

    static func headingFont(level: Int, theme: QuillTheme) -> UIFont {
        theme.headingFontScaled(level: level)
    }

    static func makeAlignedListItemParagraphStyle(
        bodyFont: UIFont,
        marker: String,
        nestingContext: NestingContext,
        theme: QuillTheme
    ) -> NSMutableParagraphStyle {
        let style = makeListParagraphStyle(
            bodyFont: bodyFont,
            level: nestingContext.listLevel,
            marker: marker,
            theme: theme
        )
        style.firstLineHeadIndent = style.headIndent
        applyBlockquoteIndent(to: style, nestingContext: nestingContext, theme: theme)
        return style
    }

    static func makeListItemMarkerParagraphStyle(
        bodyFont: UIFont,
        marker: String,
        nestingContext: NestingContext,
        theme: QuillTheme
    ) -> NSMutableParagraphStyle {
        let style = makeListParagraphStyle(
            bodyFont: bodyFont,
            level: nestingContext.listLevel,
            marker: marker,
            theme: theme
        )
        applyBlockquoteIndent(to: style, nestingContext: nestingContext, theme: theme)
        return style
    }

    static func makeListParagraphStyle(
        bodyFont: UIFont,
        level: Int,
        marker: String,
        theme: QuillTheme
    ) -> NSMutableParagraphStyle {
        let baseIndent = CGFloat(level) * theme.listIndentPerLevelScaled
        let markerWidth = (marker as NSString).size(withAttributes: [.font: bodyFont]).width
        let indent = baseIndent + markerWidth

        let style = NSMutableParagraphStyle()
        style.firstLineHeadIndent = baseIndent
        style.headIndent = indent
        style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
        style.defaultTabInterval = indent
        style.paragraphSpacingBefore = theme.listItemSpacingScaled
        return style
    }

    static func makeParagraphStyle(
        nestingContext: NestingContext,
        paragraphSpacingBefore: CGFloat,
        theme: QuillTheme
    ) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = paragraphSpacingBefore
        applyBlockquoteIndent(to: style, nestingContext: nestingContext, theme: theme)
        return style
    }

    static func makePresentationRoleParagraphStyle(
        nestingContext: NestingContext,
        paragraphSpacingBefore: CGFloat,
        presentationRole: RenderFragment.PresentationRole,
        theme: QuillTheme
    ) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacingBefore = paragraphSpacingBefore
        applyPresentationRoleIndent(
            to: style,
            nestingContext: nestingContext,
            presentationRole: presentationRole,
            theme: theme
        )
        return style
    }

    static func makeThematicBreakParagraphStyle(theme: QuillTheme) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacingBefore = theme.thematicBreakSpacingScaled
        return style
    }

    static func monospaceFont(theme: QuillTheme) -> UIFont {
        theme.codeBlock.font
    }
}

private extension BlockStyleFactory {
    static func applyBlockquoteIndent(
        to style: NSMutableParagraphStyle,
        nestingContext: NestingContext,
        theme: QuillTheme
    ) {
        guard nestingContext.blockquoteDepth > 0 else { return }

        let indent = CGFloat(nestingContext.blockquoteDepth) * theme.blockquoteLevelSpacingScaled
        style.headIndent += indent
        style.firstLineHeadIndent += indent
    }

    static func applyNestedBlockIndent(
        to style: NSMutableParagraphStyle,
        nestingContext: NestingContext,
        theme: QuillTheme
    ) {
        applyBlockquoteIndent(to: style, nestingContext: nestingContext, theme: theme)

        guard nestingContext.listLevel > 0 else { return }

        let indent = CGFloat(nestingContext.listLevel) * theme.listIndentPerLevelScaled
            + theme.body.font.pointSize * 0.75
        style.headIndent += indent
        style.firstLineHeadIndent += indent
    }

    static func applyPresentationRoleIndent(
        to style: NSMutableParagraphStyle,
        nestingContext: NestingContext,
        presentationRole: RenderFragment.PresentationRole,
        theme: QuillTheme
    ) {
        switch presentationRole {
        case .fullWidthEmbeddedBlock, .regularBlock, .standaloneListMarker:
            applyBlockquoteIndent(to: style, nestingContext: nestingContext, theme: theme)
        case .indentedListBlock, .indentedListText:
            applyNestedBlockIndent(to: style, nestingContext: nestingContext, theme: theme)
        }
    }
}
