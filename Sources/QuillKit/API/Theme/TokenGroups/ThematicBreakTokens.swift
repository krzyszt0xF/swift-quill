import UIKit

public extension QuillTheme {
    /// Thematic break is a mutable value treated as read-only after cross-actor handoff.
    struct ThematicBreak: @unchecked Sendable {
        public var color: UIColor
        public var spacing: SpacingValue

        public init(color: UIColor, spacing: SpacingValue) {
            self.color = color
            self.spacing = spacing
        }
    }
}
