import Foundation
import UIKit

public extension QuillTheme {
    /// Link is a mutable value treated as read-only after cross-actor handoff.
    struct Link: @unchecked Sendable {
        public var color: UIColor
        public var underlineStyle: NSUnderlineStyle

        public init(color: UIColor, underlineStyle: NSUnderlineStyle) {
            self.color = color
            self.underlineStyle = underlineStyle
        }
    }
}
