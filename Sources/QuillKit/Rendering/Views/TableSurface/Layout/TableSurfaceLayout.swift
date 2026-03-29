import UIKit

struct TableSurfaceLayout {
    let cells: [TableSurfaceCellLayout]
    let contentSize: CGSize
    let horizontalSeparatorYPositions: [CGFloat]
    let verticalSeparatorXPositions: [CGFloat]

    static var empty: TableSurfaceLayout {
        TableSurfaceLayout(
            cells: [],
            contentSize: CGSize(width: 320, height: 44),
            horizontalSeparatorYPositions: [],
            verticalSeparatorXPositions: []
        )
    }
}

struct TableSurfaceCellLayout {
    let attributedText: NSAttributedString
    let columnIndex: Int
    let frame: CGRect
    let plainText: String
    let rowIndex: Int
    let textFrame: CGRect
    let textLayout: TableSurfaceTextLayout
}

extension TableSurfaceLayout {
    func cell(at point: CGPoint) -> TableSurfaceCellLayout? {
        cells.first { $0.frame.contains(point) }
    }

    func handleFrames(for selection: TableSurfaceSelection) -> (leading: CGRect, trailing: CGRect)? {
        let rects = selectionRects(for: selection)
        guard let first = rects.first,
              let last = rects.last else {
            return nil
        }

        let leading = CGRect(
            x: first.minX - 11,
            y: first.minY - 14,
            width: 22,
            height: 28
        )
        let trailing = CGRect(
            x: last.maxX - 11,
            y: last.maxY - 14,
            width: 22,
            height: 28
        )

        return (leading, trailing)
    }

    func link(at point: CGPoint) -> URL? {
        guard let cell = cell(at: point) else { return nil }
        let localPoint = CGPoint(
            x: point.x - cell.textFrame.minX,
            y: point.y - cell.textFrame.minY
        )
        return cell.textLayout.link(at: localPoint)
    }

    func makeTSV(selection: TableSurfaceSelection) -> String {
        let lowerBound = selection.lowerBound
        let upperBound = selection.upperBound
        let grouped = Dictionary(grouping: cells) { $0.rowIndex }

        let rows = grouped.keys.sorted().compactMap { rowIndex -> String? in
            let rowCells = grouped[rowIndex]?.sorted { $0.columnIndex < $1.columnIndex } ?? []
            let values = rowCells.compactMap { cell -> String? in
                guard let range = selectedCharacterRange(
                    in: cell,
                    lowerBound: lowerBound,
                    upperBound: upperBound
                ) else {
                    return nil
                }

                guard range.length > 0 else { return "" }
                return cell.attributedText.attributedSubstring(from: range).string
            }

            guard values.isEmpty == false else { return nil }
            return values.joined(separator: "\t")
        }

        return rows.joined(separator: "\n")
    }

    func nearestCell(to point: CGPoint) -> TableSurfaceCellLayout? {
        cells.min { lhs, rhs in
            distanceSquared(from: point, to: lhs.frame) < distanceSquared(from: point, to: rhs.frame)
        }
    }

    func selectionPosition(at point: CGPoint) -> TableSurfaceSelectionPosition? {
        guard let cell = cell(at: point) ?? nearestCell(to: point) else { return nil }

        let localPoint = CGPoint(
            x: point.x - cell.textFrame.minX,
            y: point.y - cell.textFrame.minY
        )
        let characterIndex = cell.textLayout.characterIndex(at: localPoint)

        return TableSurfaceSelectionPosition(
            characterIndex: characterIndex,
            columnIndex: cell.columnIndex,
            rowIndex: cell.rowIndex
        )
    }

    func selectionRects(for selection: TableSurfaceSelection) -> [CGRect] {
        let lowerBound = selection.lowerBound
        let upperBound = selection.upperBound

        return cells.flatMap { cell -> [CGRect] in
            guard let range = selectedCharacterRange(
                in: cell,
                lowerBound: lowerBound,
                upperBound: upperBound
            ) else {
                return []
            }

            if cell.attributedText.length == 0 {
                return [
                    CGRect(
                        x: cell.textFrame.minX,
                        y: cell.textFrame.minY,
                        width: max(8, cell.textFrame.width * 0.35),
                        height: cell.textFrame.height
                    ),
                ]
            }

            return cell.textLayout.selectionRects(for: range).map {
                $0.offsetBy(dx: cell.textFrame.minX, dy: cell.textFrame.minY)
            }
        }
    }
}

private extension TableSurfaceLayout {
    func distanceSquared(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(max(rect.minX - point.x, 0), point.x - rect.maxX)
        let dy = max(max(rect.minY - point.y, 0), point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    func selectedCharacterRange(
        in cell: TableSurfaceCellLayout,
        lowerBound: TableSurfaceSelectionPosition,
        upperBound: TableSurfaceSelectionPosition
    ) -> NSRange? {
        let cellStart = TableSurfaceSelectionPosition(
            characterIndex: 0,
            columnIndex: cell.columnIndex,
            rowIndex: cell.rowIndex
        )
        let cellEnd = TableSurfaceSelectionPosition(
            characterIndex: cell.attributedText.length,
            columnIndex: cell.columnIndex,
            rowIndex: cell.rowIndex
        )

        guard upperBound >= cellStart, lowerBound <= cellEnd else { return nil }

        let start = if lowerBound.rowIndex == cell.rowIndex && lowerBound.columnIndex == cell.columnIndex {
            min(lowerBound.characterIndex, cell.attributedText.length)
        } else {
            0
        }
        let end = if upperBound.rowIndex == cell.rowIndex && upperBound.columnIndex == cell.columnIndex {
            min(upperBound.characterIndex, cell.attributedText.length)
        } else {
            cell.attributedText.length
        }

        return NSRange(location: min(start, end), length: max(0, end - start))
    }
}
