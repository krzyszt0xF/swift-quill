import UIKit

extension NSAttributedString {
    func containsAttachment<T: NSTextAttachment>(_ attachmentType: T.Type) -> Bool {
        guard length > 0 else { return false }

        var found = false
        enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: length)
        ) { value, _, stop in
            guard value is T else { return }
            found = true
            stop.pointee = true
        }

        return found
    }

    var firstAttachmentIndex: Int? {
        guard length > 0 else { return nil }

        var index: Int?
        enumerateAttribute(
            .attachment,
            in: NSRange(location: 0, length: length)
        ) { value, range, stop in
            guard value is NSTextAttachment else { return }
            index = range.location
            stop.pointee = true
        }

        return index
    }
}
