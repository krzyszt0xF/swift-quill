import UIKit

public extension QuillTheme {
    // @unchecked Sendable: UIFont, UIColor, and UIEdgeInsets are not Sendable; Table values are immutable snapshots once constructed and carried across actor boundaries without mutation.
    /// Table is a mutable value treated as read-only after cross-actor handoff.
    struct Table: @unchecked Sendable {
        public var bodyFont: UIFont
        public var cellPadding: UIEdgeInsets
        public var headerFont: UIFont
        public var minimumRowHeight: CGFloat
        public var separatorColor: UIColor
        public var separatorWidth: CGFloat

        public init(
            bodyFont: UIFont,
            cellPadding: UIEdgeInsets,
            headerFont: UIFont,
            minimumRowHeight: CGFloat,
            separatorColor: UIColor,
            separatorWidth: CGFloat
        ) {
            self.bodyFont = bodyFont
            self.cellPadding = cellPadding
            self.headerFont = headerFont
            self.minimumRowHeight = minimumRowHeight
            self.separatorColor = separatorColor
            self.separatorWidth = separatorWidth
        }
    }
}
