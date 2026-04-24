import UIKit

public extension QuillTheme {
    // @unchecked Sendable: UIColor is not Sendable; Image values are immutable snapshots once constructed and carried across actor boundaries without mutation.
    /// Image is a mutable value treated as read-only after cross-actor handoff.
    struct Image: @unchecked Sendable {
        public var altTextColor: UIColor
        public var cornerRadius: CGFloat
        public var errorIconColor: UIColor
        public var fallbackAspectRatio: CGFloat
        public var maxHeight: CGFloat
        public var placeholderColor: UIColor

        public init(
            altTextColor: UIColor,
            cornerRadius: CGFloat,
            errorIconColor: UIColor,
            fallbackAspectRatio: CGFloat,
            maxHeight: CGFloat,
            placeholderColor: UIColor
        ) {
            self.altTextColor = altTextColor
            self.cornerRadius = cornerRadius
            self.errorIconColor = errorIconColor
            self.fallbackAspectRatio = fallbackAspectRatio
            self.maxHeight = maxHeight
            self.placeholderColor = placeholderColor
        }
    }
}
