import UIKit

extension QuillTheme {
    var blockquoteLevelSpacingScaled: CGFloat {
        blockquote.levelSpacing.scale(against: body.font.pointSize)
    }

    var blockSpacingScaled: CGFloat {
        spacing.blockSpacing.scale(against: body.font.pointSize)
    }

    func headingFontScaled(level: Int) -> UIFont {
        let fontScale = heading.fontScale(for: level).scale(against: body.font.pointSize)
        return .systemFont(ofSize: fontScale, weight: heading.fontWeight(for: level))
    }

    var headingSpacingScaled: CGFloat {
        heading.spacingBefore.scale(against: body.font.pointSize)
    }

    var listIndentPerLevelScaled: CGFloat {
        list.indentPerLevel.scale(against: body.font.pointSize)
    }

    var listItemSpacingScaled: CGFloat {
        list.itemSpacing.scale(against: body.font.pointSize)
    }

    var thematicBreakSpacingScaled: CGFloat {
        thematicBreak.spacing.scale(against: body.font.pointSize)
    }
}
