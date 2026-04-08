import UIKit

public extension QuillTheme {
    /// Inline is a mutable value treated as read-only after cross-actor handoff.
    struct Inline: @unchecked Sendable {
        public var backgroundColor: UIColor
        public var fontSizeOffset: CGFloat
        public var textColor: UIColor

        public init(
            backgroundColor: UIColor,
            fontSizeOffset: CGFloat,
            textColor: UIColor
        ) {
            self.backgroundColor = backgroundColor
            self.fontSizeOffset = fontSizeOffset
            self.textColor = textColor
        }
    }
}
