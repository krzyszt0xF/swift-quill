struct TableSurfaceSelection {
    let anchor: TableSurfaceSelectionPosition
    let focus: TableSurfaceSelectionPosition

    var lowerBound: TableSurfaceSelectionPosition {
        min(anchor, focus)
    }

    var upperBound: TableSurfaceSelectionPosition {
        max(anchor, focus)
    }
}

struct TableSurfaceSelectionPosition: Comparable {
    let characterIndex: Int
    let columnIndex: Int
    let rowIndex: Int

    static func < (lhs: TableSurfaceSelectionPosition, rhs: TableSurfaceSelectionPosition) -> Bool {
        if lhs.rowIndex != rhs.rowIndex {
            return lhs.rowIndex < rhs.rowIndex
        }
        if lhs.columnIndex != rhs.columnIndex {
            return lhs.columnIndex < rhs.columnIndex
        }
        return lhs.characterIndex < rhs.characterIndex
    }
}
