import UIKit

public extension QuillTheme {
    // @unchecked Sendable: UIFont.Weight is not Sendable; Heading values are immutable snapshots once constructed and carried across actor boundaries without mutation.
    /// Heading is a mutable value treated as read-only after cross-actor handoff.
    struct Heading: @unchecked Sendable, Equatable {
        public var fontScales: [SpacingValue]
        public var fontWeights: [UIFont.Weight]
        public var spacingBefore: SpacingValue

        public init(
            fontScales: [SpacingValue],
            fontWeights: [UIFont.Weight],
            spacingBefore: SpacingValue
        ) {
            self.fontScales = fontScales
            self.fontWeights = fontWeights
            self.spacingBefore = spacingBefore
        }

        public func fontScale(for level: Int) -> SpacingValue {
            let index = max(0, min(level - 1, fontScales.count - 1))
            guard fontScales.indices.contains(index) else { return .relative(1) }
            return fontScales[index]
        }

        public func fontWeight(for level: Int) -> UIFont.Weight {
            let index = max(0, min(level - 1, fontWeights.count - 1))
            guard fontWeights.indices.contains(index) else { return .regular }
            return fontWeights[index]
        }
    }
}
