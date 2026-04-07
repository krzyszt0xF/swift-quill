import UIKit

public extension QuillTheme {
    /// Blockquote is a mutable value treated as read-only after cross-actor handoff.
    struct Blockquote: @unchecked Sendable {
        public var barColor: UIColor
        public var barCornerRadius: CGFloat
        public var barLeadingInset: CGFloat
        public var barWidth: CGFloat
        public var levelSpacing: SpacingValue
        public var textColor: UIColor

        public init(
            barColor: UIColor,
            barCornerRadius: CGFloat,
            barLeadingInset: CGFloat,
            barWidth: CGFloat,
            levelSpacing: SpacingValue,
            textColor: UIColor
        ) {
            self.barColor = barColor
            self.barCornerRadius = barCornerRadius
            self.barLeadingInset = barLeadingInset
            self.barWidth = barWidth
            self.levelSpacing = levelSpacing
            self.textColor = textColor
        }
    }
}
