import UIKit

public extension QuillTheme {
    // @unchecked Sendable: UIFont and UIColor are not Sendable; CodeBlock values are immutable snapshots once constructed and carried across actor boundaries without mutation.
    /// Code block is a mutable value treated as read-only after cross-actor handoff.
    struct CodeBlock: @unchecked Sendable, Equatable {
        public var backgroundColor: UIColor
        public var borderColor: UIColor
        public var borderWidth: CGFloat
        public var copyButtonTint: UIColor
        public var cornerRadius: CGFloat
        public var font: UIFont
        public var headerFont: UIFont
        public var languageLabelColor: UIColor
        public var lineSpacing: CGFloat
        public var padding: CGFloat
        public var textColor: UIColor

        public init(
            backgroundColor: UIColor,
            borderColor: UIColor,
            borderWidth: CGFloat,
            copyButtonTint: UIColor,
            cornerRadius: CGFloat,
            font: UIFont,
            headerFont: UIFont,
            languageLabelColor: UIColor,
            lineSpacing: CGFloat,
            padding: CGFloat,
            textColor: UIColor
        ) {
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
            self.copyButtonTint = copyButtonTint
            self.cornerRadius = cornerRadius
            self.font = font
            self.headerFont = headerFont
            self.languageLabelColor = languageLabelColor
            self.lineSpacing = lineSpacing
            self.padding = padding
            self.textColor = textColor
        }
    }
}
