import UIKit

public extension QuillTheme {
    /// Body text is a mutable value treated as read-only after cross-actor handoff.
    struct Body: @unchecked Sendable {
        public var font: UIFont
        public var textColor: UIColor

        public init(font: UIFont, textColor: UIColor) {
            self.font = font
            self.textColor = textColor
        }
    }
}
