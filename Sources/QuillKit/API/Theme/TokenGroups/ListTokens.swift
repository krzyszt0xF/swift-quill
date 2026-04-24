import Foundation

public extension QuillTheme {
    // @unchecked Sendable: the stored property types (String, SpacingValue) are themselves Sendable, but unchecked conformance is used for consistency with sibling token groups that hold non-Sendable UIKit types. List values are immutable snapshots once constructed.
    /// List is a mutable value treated as read-only after cross-actor handoff.
    struct List: @unchecked Sendable {
        public var bulletMarker: String
        public var checkedMarker: String
        public var indentPerLevel: SpacingValue
        public var itemSpacing: SpacingValue
        public var uncheckedMarker: String

        public init(
            bulletMarker: String,
            checkedMarker: String,
            indentPerLevel: SpacingValue,
            itemSpacing: SpacingValue,
            uncheckedMarker: String
        ) {
            self.bulletMarker = bulletMarker
            self.checkedMarker = checkedMarker
            self.indentPerLevel = indentPerLevel
            self.itemSpacing = itemSpacing
            self.uncheckedMarker = uncheckedMarker
        }
    }
}
