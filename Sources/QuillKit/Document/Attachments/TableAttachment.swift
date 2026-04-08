import QuillCore
import UIKit

final class TableAttachment: NSTextAttachment {
    let blockID: BlockIdentity
    let columnAlignments: [Block.ColumnAlignment?]
    let header: Block.TableRow
    let rows: [Block.TableRow]
    let theme: QuillTheme

    init(
        blockID: BlockIdentity,
        columnAlignments: [Block.ColumnAlignment?],
        header: Block.TableRow,
        rows: [Block.TableRow],
        theme: QuillTheme
    ) {
        self.blockID = blockID
        self.columnAlignments = columnAlignments
        self.header = header
        self.rows = rows
        self.theme = theme
        super.init(data: nil, ofType: nil)

        allowsTextAttachmentView = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewProvider(
        for parentView: UIView?,
        location: any NSTextLocation,
        textContainer: NSTextContainer?
    ) -> NSTextAttachmentViewProvider? {
        TableAttachmentProvider(
            textAttachment: self,
            parentView: parentView,
            textLayoutManager: textContainer?.textLayoutManager,
            location: location
        )
    }
}
