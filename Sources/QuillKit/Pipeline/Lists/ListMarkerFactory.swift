import QuillCore

enum ListMarkerFactory {
    static func makeOrderedListMarker(
        checkbox: Block.Checkbox?,
        itemIndex: Int,
        startIndex: UInt
    ) -> String {
        let prefix = "\(Int(startIndex) + itemIndex)."

        guard let checkbox else {
            return "\(prefix)\t"
        }

        return "\(prefix) \(makeTaskListMarker(for: checkbox))\t"
    }

    static func makeTaskListMarker(for checkbox: Block.Checkbox) -> String {
        switch checkbox {
        case .checked:
            return "[x]"
        case .unchecked:
            return "[ ]"
        }
    }

    static func makeUnorderedBullet(for listLevel: Int) -> String {
        switch listLevel {
        case 0:
            return "+"
        case 1:
            return "-"
        default:
            return "*"
        }
    }

    static func makeUnorderedListMarker(
        bullet: String,
        checkbox: Block.Checkbox?
    ) -> String {
        guard let checkbox else {
            return "\(bullet)\t"
        }

        return "\(makeTaskListMarker(for: checkbox))\t"
    }
}
