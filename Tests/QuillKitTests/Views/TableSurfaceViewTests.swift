@testable import QuillKit
import QuillCore
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("TableSurfaceView", GloballySerialized(), .tags(.rendering))
struct TableSurfaceViewTests {
    @Test("copy clears custom selection after writing TSV")
    func copyClearsSelectionAfterWritingTSV() {
        var copiedText: String?
        let view = makeView {
            copiedText = $0
        }

        #expect(view.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil))

        view.copy(nil)

        #expect(copiedText == "Streaming tail\tlive")
        #expect(hasSelection(view) == false)
        #expect(view.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil) == false)
    }

    @Test("share action remains available for active selection")
    func shareActionRemainsAvailable() {
        let view = makeView()

        #expect(view.canPerformAction(#selector(TableSurfaceView.share(_:)), withSender: nil))
    }

    @Test("layout reuses cached text layouts for same content and width")
    func layoutReusesCachedTextLayouts() throws {
        let view = makeView()
        let initialTextLayout = try #require(firstTextLayout(in: view))

        view.layoutIfNeeded()

        let reusedTextLayout = try #require(firstTextLayout(in: view))
        #expect(initialTextLayout === reusedTextLayout)
    }

    @Test("configure invalidates cached layout for new content")
    func configureInvalidatesCachedLayoutForNewContent() throws {
        let view = makeView()
        let initialTextLayout = try #require(firstTextLayout(in: view))

        view.configure(
            content: makeContent(
                header: ["Feature", "State"],
                rows: [["Code highlighting", "updated"]]
            )
        )
        view.layoutIfNeeded()

        let updatedTextLayout = try #require(firstTextLayout(in: view))
        #expect(initialTextLayout !== updatedTextLayout)
    }
}

private extension TableSurfaceViewTests {
    func firstTextLayout(in view: TableSurfaceView) -> TableSurfaceTextLayout? {
        let canvasView: TableSurfaceCanvasView? = view.firstSubview()
        return canvasView?.layoutModel.cells.first?.textLayout
    }

    func hasSelection(_ view: TableSurfaceView) -> Bool {
        if case .some = view.selection {
            return true
        }

        return false
    }

    func makeView(onCopy: @escaping OnCopy = { _ in }) -> TableSurfaceView {
        let view = TableSurfaceView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        view.onCopy = onCopy
        view.configure(
            content: makeContent(
                header: ["Feature", "State"],
                rows: [["Streaming tail", "live"]]
            )
        )
        view.layoutIfNeeded()
        view.selection = TableSurfaceSelection(
            anchor: TableSurfaceSelectionPosition(
                characterIndex: 0,
                columnIndex: 0,
                rowIndex: 1
            ),
            focus: TableSurfaceSelectionPosition(
                characterIndex: 4,
                columnIndex: 1,
                rowIndex: 1
            )
        )
        return view
    }

    func makeContent(header: [String], rows: [[String]]) -> TableSurfaceContent {
        TableSurfaceContent(
            columnAlignments: Array(
                repeating: Block.ColumnAlignment.left as Block.ColumnAlignment?,
                count: header.count
            ),
            header: TableSurfaceRowContent(cells: header.map(makeCell)),
            rows: rows.map { row in
                TableSurfaceRowContent(cells: row.map(makeCell))
            }
        )
    }

    func makeCell(_ text: String) -> TableSurfaceCellContent {
        let attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.label,
            ]
        )

        return TableSurfaceCellContent(
            attributedText: attributedText,
            plainText: text
        )
    }
}
