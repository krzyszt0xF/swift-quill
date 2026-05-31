import UIKit

public extension QuillTheme {
    // @unchecked Sendable: UIColor is not Sendable; ThematicBreak values are immutable snapshots once constructed and carried across actor boundaries without mutation.
    /// Thematic break is a mutable value treated as read-only after cross-actor handoff.
    struct ThematicBreak: @unchecked Sendable, Equatable {
        public var color: UIColor
        public var spacing: SpacingValue

        public init(color: UIColor, spacing: SpacingValue) {
            self.color = color
            self.spacing = spacing
        }
    }
}
