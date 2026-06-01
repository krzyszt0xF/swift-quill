import UIKit

public extension QuillTheme {
    // @unchecked Sendable: UIFont and UIColor are not Sendable; Body values are immutable snapshots once constructed and carried across actor boundaries without mutation.
    /// Body text is a mutable value treated as read-only after cross-actor handoff.
    struct Body: @unchecked Sendable, Equatable {
        public var font: UIFont
        public var textColor: UIColor

        public init(font: UIFont, textColor: UIColor) {
            self.font = font
            self.textColor = textColor
        }
    }
}
