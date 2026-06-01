import Foundation
import UIKit

public extension QuillTheme {
    // @unchecked Sendable: UIColor and NSUnderlineStyle are not Sendable; Link values are immutable snapshots once constructed and carried across actor boundaries without mutation.
    /// Link is a mutable value treated as read-only after cross-actor handoff.
    struct Link: @unchecked Sendable, Equatable {
        public var color: UIColor
        public var underlineStyle: NSUnderlineStyle

        public init(color: UIColor, underlineStyle: NSUnderlineStyle) {
            self.color = color
            self.underlineStyle = underlineStyle
        }
    }
}
