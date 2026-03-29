import Foundation
import QuillCore
import UIKit

struct TableSurfaceContent: Sendable {
    let columnAlignments: [Block.ColumnAlignment?]
    let header: TableSurfaceRowContent
    let rows: [TableSurfaceRowContent]
}

struct TableSurfaceRowContent: Sendable {
    let cells: [TableSurfaceCellContent]
}

struct TableSurfaceCellContent: @unchecked Sendable {
    let attributedText: NSAttributedString
    let plainText: String
}

extension TableSurfaceContent {
    init(from attachment: TableAttachment) {
        self.init(
            columnAlignments: attachment.columnAlignments,
            header: TableSurfaceRowContent(from: attachment.header, isHeader: true),
            rows: attachment.rows.map { TableSurfaceRowContent(from: $0, isHeader: false) }
        )
    }
}

private extension TableSurfaceRowContent {
    init(from row: Block.TableRow, isHeader: Bool) {
        self.init(
            cells: row.cells.map { TableSurfaceCellContent(from: $0, isHeader: isHeader) }
        )
    }
}

private extension TableSurfaceCellContent {
    init(from cell: Block.TableCell, isHeader: Bool) {
        let baseFont = isHeader
            ? UIFont.monospacedSystemFont(ofSize: 14, weight: .semibold)
            : UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        self.init(
            attributedText: InlineContentRenderer.attributedString(
                for: cell.content,
                baseFont: baseFont
            ),
            plainText: InlineContentRenderer.plainText(from: cell.content)
        )
    }
}
