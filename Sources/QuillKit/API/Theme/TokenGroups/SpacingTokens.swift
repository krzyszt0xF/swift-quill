public extension QuillTheme {
    /// Shared spacing tokens carried as an immutable sendable snapshot.
    struct Spacing: @unchecked Sendable {
        public var blockSpacing: SpacingValue

        public init(blockSpacing: SpacingValue) {
            self.blockSpacing = blockSpacing
        }
    }
}
