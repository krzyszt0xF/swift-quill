@testable import QuillKit
import QuillCore
import QuillSharedTestSupport
import Testing
import UIKit

@Suite("TableSurfaceLayout", .tags(.rendering))
struct TableSurfaceLayoutTests {
    @Test("Long token wraps inside a constrained column")
    func longTokenWraps() throws {
        let layout = TableSurfaceLayoutBuilder.makeLayout(
            content: makeContent(
                header: ["Token", "Value"],
                rows: [[
                    "supercalifragilisticexpialidocious_without_spaces",
                    "ok",
                ]]
            ),
            viewportWidth: 220
        )

        let tokenCell = try #require(layout.cells.first { $0.rowIndex == 1 && $0.columnIndex == 0 })
        #expect(tokenCell.textLayout.usedHeight > 20)
        #expect(tokenCell.textFrame.width <= tokenCell.frame.width)
    }

    @Test("Narrow tables stretch to the viewport width")
    func narrowTablesStretch() {
        let layout = TableSurfaceLayoutBuilder.makeLayout(
            content: makeContent(
                header: ["Name", "Age"],
                rows: [["Ana", "30"]]
            ),
            viewportWidth: 320
        )

        #expect(layout.contentSize.width == 320)
    }

    @Test("Selection serializes visible cells as TSV")
    func selectionSerializesAsTSV() {
        let layout = TableSurfaceLayoutBuilder.makeLayout(
            content: makeContent(
                header: ["Feature", "State"],
                rows: [
                    ["Streaming tail", "live"],
                    ["Code freeze swap", "stable"],
                ]
            ),
            viewportWidth: 320
        )

        let selection = TableSurfaceSelection(
            anchor: TableSurfaceSelectionPosition(characterIndex: 0, columnIndex: 0, rowIndex: 0),
            focus: TableSurfaceSelectionPosition(characterIndex: 6, columnIndex: 1, rowIndex: 2)
        )

        let tsv = layout.makeTSV(selection: selection)

        #expect(tsv.contains("Feature\tState"))
        #expect(tsv.contains("Streaming tail\tlive"))
        #expect(tsv.contains("Code freeze swap\tstable"))
    }

    @Test("Link hit testing resolves URLs from cell text")
    func linkHitTesting() throws {
        let content = TableSurfaceContent(
            columnAlignments: [Block.ColumnAlignment.left as Block.ColumnAlignment?],
            header: TableSurfaceRowContent(cells: [
                TableSurfaceCellContent(
                    attributedText: NSAttributedString(string: "Docs"),
                    plainText: "Docs"
                ),
            ]),
            rows: [
                TableSurfaceRowContent(cells: [
                    TableSurfaceCellContent(
                        attributedText: NSMutableAttributedString(
                            string: "example.com",
                            attributes: [.link: URL(string: "https://example.com")!]
                        ),
                        plainText: "example.com"
                    ),
                ]),
            ]
        )
        let layout = TableSurfaceLayoutBuilder.makeLayout(content: content, viewportWidth: 240)
        let linkCell = try #require(layout.cells.first { $0.rowIndex == 1 && $0.columnIndex == 0 })
        let point = CGPoint(x: linkCell.textFrame.minX + 3, y: linkCell.textFrame.midY)

        let url = layout.link(at: point)

        #expect(url == URL(string: "https://example.com"))
    }
}

private extension TableSurfaceLayoutTests {
    func makeContent(header: [String], rows: [[String]]) -> TableSurfaceContent {
        TableSurfaceContent(
            columnAlignments: Array(repeating: Block.ColumnAlignment.left as Block.ColumnAlignment?, count: header.count),
            header: TableSurfaceRowContent(cells: header.map(makeCell)),
            rows: rows.map { row in
                TableSurfaceRowContent(cells: row.map(makeCell))
            }
        )
    }

    func makeCell(_ text: String) -> TableSurfaceCellContent {
        let attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor.label,
        ])
        return TableSurfaceCellContent(
            attributedText: attributedText,
            plainText: text
        )
    }
}
