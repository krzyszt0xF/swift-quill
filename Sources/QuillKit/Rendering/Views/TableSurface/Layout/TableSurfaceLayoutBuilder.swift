import QuillCore
import UIKit

enum TableSurfaceLayoutBuilder {
    static func makeLayout(
        content: TableSurfaceContent,
        viewportWidth: CGFloat,
        theme: QuillTheme = .default
    ) -> TableSurfaceLayout {
        let rows = [content.header] + content.rows
        let columnCount = max(
            content.columnAlignments.count,
            content.header.cells.count,
            content.rows.map(\.cells.count).max() ?? 0
        )
        guard columnCount > 0 else { return .empty }

        let naturalColumnWidths = makeNaturalColumnWidths(
            columnAlignments: content.columnAlignments,
            columnCount: columnCount,
            rows: rows,
            theme: theme
        )
        let columnWidths = makeColumnWidths(
            naturalWidths: naturalColumnWidths,
            viewportWidth: viewportWidth,
            theme: theme
        )

        var xOffsets: [CGFloat] = []
        var runningX: CGFloat = 0
        for (index, width) in columnWidths.enumerated() {
            xOffsets.append(runningX)
            runningX += width
            if index < columnWidths.count - 1 {
                runningX += theme.table.separatorWidth
            }
        }

        let totalWidth = runningX
        var horizontalSeparatorYPositions: [CGFloat] = []
        var cells: [TableSurfaceCellLayout] = []
        var yOffset: CGFloat = 0

        for (rowIndex, row) in rows.enumerated() {
            let cellLayouts = makeRowLayouts(
                columnAlignments: content.columnAlignments,
                columnCount: columnCount,
                columnWidths: columnWidths,
                row: row,
                rowIndex: rowIndex,
                xOffsets: xOffsets,
                theme: theme
            )
            let rowHeight = cellLayouts.reduce(theme.table.minimumRowHeight) { partialResult, cell in
                max(
                    partialResult,
                    cell.textLayout.usedHeight + theme.table.cellPadding.top + theme.table.cellPadding.bottom)
            }

            cells.append(contentsOf: positionRowLayouts(
                cellLayouts,
                rowHeight: rowHeight,
                yOffset: yOffset,
                theme: theme
            ))

            yOffset += rowHeight
            if rowIndex < rows.count - 1 {
                horizontalSeparatorYPositions.append(yOffset)
                yOffset += theme.table.separatorWidth
            }
        }

        let verticalSeparatorXPositions = xOffsets.dropFirst().map { $0 - theme.table.separatorWidth / 2 }

        return TableSurfaceLayout(
            cells: cells,
            contentSize: CGSize(width: totalWidth, height: yOffset),
            horizontalSeparatorYPositions: horizontalSeparatorYPositions,
            verticalSeparatorXPositions: verticalSeparatorXPositions
        )
    }
}

private extension TableSurfaceLayoutBuilder {
    enum Layout {
        static let maximumColumnWidth: CGFloat = 320
        static let minimumColumnWidth: CGFloat = 96
    }

    static func makeAlignedText(
        attributedText: NSAttributedString,
        alignment: Block.ColumnAlignment?
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: attributedText)
        let style = NSMutableParagraphStyle()
        style.alignment = textAlignment(for: alignment)
        style.lineBreakMode = .byCharWrapping
        if result.length > 0 {
            result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        }
        return result
    }

    static func makeCellLayout(
        alignment: Block.ColumnAlignment?,
        cell: TableSurfaceCellContent,
        columnIndex: Int,
        rowIndex: Int,
        width: CGFloat,
        xOffset: CGFloat,
        theme: QuillTheme
    ) -> TableSurfaceCellLayout {
        let textFrame = CGRect(
            x: xOffset + theme.table.cellPadding.left,
            y: 0,
            width: max(1, width - theme.table.cellPadding.left - theme.table.cellPadding.right),
            height: 0
        )
        let textLayout = TableSurfaceTextLayout(
            attributedText: makeAlignedText(
                attributedText: cell.attributedText,
                alignment: alignment
            ),
            width: textFrame.width
        )
        let cellFrame = CGRect(
            x: xOffset,
            y: 0,
            width: width,
            height: 0
        )

        return TableSurfaceCellLayout(
            attributedText: textLayout.attributedText,
            columnIndex: columnIndex,
            frame: cellFrame,
            plainText: cell.plainText,
            rowIndex: rowIndex,
            textFrame: textFrame,
            textLayout: textLayout
        )
    }

    static func makeColumnWidths(
        naturalWidths: [CGFloat],
        viewportWidth: CGFloat,
        theme: QuillTheme
    ) -> [CGFloat] {
        let naturalTotal = naturalWidths.reduce(0, +)
            + CGFloat(max(0, naturalWidths.count - 1)) * theme.table.separatorWidth
        guard naturalTotal < viewportWidth else { return naturalWidths }

        let extra = (viewportWidth - naturalTotal) / CGFloat(max(naturalWidths.count, 1))
        return naturalWidths.map { $0 + extra }
    }

    static func makeNaturalColumnWidths(
        columnAlignments: [Block.ColumnAlignment?],
        columnCount: Int,
        rows: [TableSurfaceRowContent],
        theme: QuillTheme
    ) -> [CGFloat] {
        (0..<columnCount).map { columnIndex in
            let widest = rows.map { row -> CGFloat in
                guard columnIndex < row.cells.count else { return Layout.minimumColumnWidth }
                let attributedText = makeAlignedText(
                    attributedText: row.cells[columnIndex].attributedText,
                    alignment: columnIndex < columnAlignments.count ? columnAlignments[columnIndex] : nil
                )
                let rawWidth = TableSurfaceTextLayout.measureSingleLineWidth(attributedText: attributedText)
                return rawWidth + theme.table.cellPadding.left + theme.table.cellPadding.right
            }.max() ?? Layout.minimumColumnWidth

            return min(max(widest, Layout.minimumColumnWidth), Layout.maximumColumnWidth)
        }
    }

    static func makeRowLayouts(
        columnAlignments: [Block.ColumnAlignment?],
        columnCount: Int,
        columnWidths: [CGFloat],
        row: TableSurfaceRowContent,
        rowIndex: Int,
        xOffsets: [CGFloat],
        theme: QuillTheme
    ) -> [TableSurfaceCellLayout] {
        (0..<columnCount).map { columnIndex in
            let cell = columnIndex < row.cells.count
                ? row.cells[columnIndex]
                : TableSurfaceCellContent(attributedText: NSAttributedString(), plainText: "")
            let alignment = columnIndex < columnAlignments.count ? columnAlignments[columnIndex] : nil
            return makeCellLayout(
                alignment: alignment,
                cell: cell,
                columnIndex: columnIndex,
                rowIndex: rowIndex,
                width: columnWidths[columnIndex],
                xOffset: xOffsets[columnIndex],
                theme: theme
            )
        }
    }

    static func positionRowLayouts(
        _ cellLayouts: [TableSurfaceCellLayout],
        rowHeight: CGFloat,
        yOffset: CGFloat,
        theme: QuillTheme
    ) -> [TableSurfaceCellLayout] {
        cellLayouts.map { cell in
            let cellFrame = CGRect(
                x: cell.frame.minX,
                y: yOffset,
                width: cell.frame.width,
                height: rowHeight
            )
            let textHeight = min(
                cell.textLayout.usedHeight,
                max(1, rowHeight - theme.table.cellPadding.top - theme.table.cellPadding.bottom)
            )
            let textFrame = CGRect(
                x: cell.textFrame.minX,
                y: yOffset + ((rowHeight - textHeight) / 2),
                width: cell.textFrame.width,
                height: textHeight
            )

            return TableSurfaceCellLayout(
                attributedText: cell.attributedText,
                columnIndex: cell.columnIndex,
                frame: cellFrame,
                plainText: cell.plainText,
                rowIndex: cell.rowIndex,
                textFrame: textFrame,
                textLayout: cell.textLayout
            )
        }
    }

    static func textAlignment(for alignment: Block.ColumnAlignment?) -> NSTextAlignment {
        switch alignment {
        case .center:
            .center
        case .right:
            .right
        default:
            .left
        }
    }
}
