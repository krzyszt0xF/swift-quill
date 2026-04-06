import UIKit

/// Visual configuration for standalone image block rendering.
public struct ImageAppearance: Sendable {
    public var errorIconColor: UIColor
    public var fallbackAspectRatio: CGFloat
    public var maxHeight: CGFloat
    public var placeholderColor: UIColor

    public init(
        placeholderColor: UIColor,
        fallbackAspectRatio: CGFloat,
        maxHeight: CGFloat,
        errorIconColor: UIColor
    ) {
        self.errorIconColor = errorIconColor
        self.fallbackAspectRatio = max(0.01, fallbackAspectRatio)
        self.maxHeight = max(1, maxHeight)
        self.placeholderColor = placeholderColor
    }
}

public extension ImageAppearance {
    static let `default` = Self(
        placeholderColor: .systemGray5,
        fallbackAspectRatio: 16.0 / 9.0,
        maxHeight: 400,
        errorIconColor: .secondaryLabel
    )
}
