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

// @unchecked Sendable: NSAttributedString is not Sendable. Cell content is built once by
// InlineContentRenderer and treated as an immutable value thereafter; the stored reference is never
// mutated or shared outside the owning TableSurfaceContent snapshot.
struct TableSurfaceCellContent: @unchecked Sendable {
    let attributedText: NSAttributedString
    let plainText: String
}

extension TableSurfaceContent {
    init(from attachment: TableAttachment) {
        self.init(
            columnAlignments: attachment.columnAlignments,
            header: TableSurfaceRowContent(
                from: attachment.header,
                isHeader: true,
                theme: attachment.theme
            ),
            rows: attachment.rows.map {
                TableSurfaceRowContent(
                    from: $0,
                    isHeader: false,
                    theme: attachment.theme
                )
            }
        )
    }
}

private extension TableSurfaceRowContent {
    init(
        from row: Block.TableRow,
        isHeader: Bool,
        theme: QuillTheme
    ) {
        self.init(
            cells: row.cells.map {
                TableSurfaceCellContent(
                    from: $0,
                    isHeader: isHeader,
                    theme: theme
                )
            }
        )
    }
}

private extension TableSurfaceCellContent {
    init(
        from cell: Block.TableCell,
        isHeader: Bool,
        theme: QuillTheme
    ) {
        let baseFont = isHeader
            ? theme.table.headerFont
            : theme.table.bodyFont
        self.init(
            attributedText: InlineContentRenderer.attributedString(
                for: cell.content,
                baseFont: baseFont,
                theme: theme
            ),
            plainText: InlineContentRenderer.plainText(from: cell.content)
        )
    }
}
