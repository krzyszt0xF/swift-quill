import UIKit

func containsAttachment<T: NSTextAttachment>(
    _ attachmentType: T.Type,
    in attributedString: NSAttributedString?
) -> Bool {
    guard let attributedString, attributedString.length > 0 else { return false }

    var found = false
    attributedString.enumerateAttribute(
        .attachment,
        in: NSRange(location: 0, length: attributedString.length)
    ) { value, _, stop in
        guard value is T else { return }
        found = true
        stop.pointee = true
    }

    return found
}

func firstAttachmentIndex(in attributedString: NSAttributedString?) -> Int? {
    guard let attributedString, attributedString.length > 0 else { return nil }

    var index: Int?
    attributedString.enumerateAttribute(
        .attachment,
        in: NSRange(location: 0, length: attributedString.length)
    ) { value, range, stop in
        guard value is NSTextAttachment else { return }
        index = range.location
        stop.pointee = true
    }

    return index
}
