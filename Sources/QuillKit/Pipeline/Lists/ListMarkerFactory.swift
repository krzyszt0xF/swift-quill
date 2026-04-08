import QuillCore

enum ListMarkerFactory {
    static func makeOrderedListMarker(
        checkbox: Block.Checkbox?,
        itemIndex: Int,
        startIndex: UInt,
        theme: QuillTheme
    ) -> String {
        guard let checkbox else {
            let prefix = "\(Int(startIndex) + itemIndex)."
            return "\(prefix)\t"
        }

        return "\(makeTaskListMarker(for: checkbox, theme: theme))\t"
    }

    static func makeTaskListMarker(
        for checkbox: Block.Checkbox,
        theme: QuillTheme
    ) -> String {
        switch checkbox {
        case .checked:
            return theme.list.checkedMarker
        case .unchecked:
            return theme.list.uncheckedMarker
        }
    }

    static func makeUnorderedBullet(theme: QuillTheme) -> String {
        theme.list.bulletMarker
    }

    static func makeUnorderedListMarker(
        bullet: String,
        checkbox: Block.Checkbox?,
        theme: QuillTheme
    ) -> String {
        guard let checkbox else {
            return "\(bullet)\t"
        }

        return "\(makeTaskListMarker(for: checkbox, theme: theme))\t"
    }
}
