public extension QuillTheme {
    // @unchecked Sendable: the stored SpacingValue payload is itself Sendable, but unchecked conformance is used for consistency with sibling token groups that hold non-Sendable UIKit types. Spacing values are immutable snapshots once constructed.
    /// Shared spacing tokens carried as an immutable sendable snapshot.
    struct Spacing: @unchecked Sendable, Equatable {
        public var blockSpacing: SpacingValue

        public init(blockSpacing: SpacingValue) {
            self.blockSpacing = blockSpacing
        }
    }
}
