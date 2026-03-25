@testable import QuillKit
import UIKit

@MainActor
func documentTextView(for view: QuillView) -> DocumentTextView? {
    findSubview(of: DocumentTextView.self, in: view)
}

@MainActor
func documentHasContent(_ view: QuillView) -> Bool {
    guard let textView = documentTextView(for: view),
          let storage = textView.contentStorage,
          let attributedString = storage.attributedString
    else { return false }
    return attributedString.length > 0
}

@MainActor
func documentHasCodeBlockAttachment(_ view: QuillView) -> Bool {
    guard let textView = documentTextView(for: view),
          let storage = textView.contentStorage,
          let attributedString = storage.attributedString
    else { return false }

    var found = false
    attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length)) { value, _, stop in
        if value is CodeBlockAttachment {
            found = true
            stop.pointee = true
        }
    }
    return found
}

@MainActor
func documentCodeBlockView(for view: QuillView) -> CodeBlockView? {
    findSubview(of: CodeBlockView.self, in: view)
}

@MainActor
func findSubview<T: UIView>(
    of type: T.Type,
    in view: UIView,
    matching predicate: ((T) -> Bool)? = nil
) -> T? {
    for subview in view.subviews {
        if let match = subview as? T, predicate?(match) ?? true {
            return match
        }

        if let nestedMatch = findSubview(of: type, in: subview, matching: predicate) {
            return nestedMatch
        }
    }

    return nil
}
