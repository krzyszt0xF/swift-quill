import UIKit

// Safety invariant: the snapshot stores an immutable copy and only exposes
// fresh copies back to main-actor UI code.
final class HighlightedCodeSnapshot: @unchecked Sendable {
    private let storage: NSAttributedString

    init(_ attributedString: NSAttributedString) {
        self.storage = NSAttributedString(attributedString: attributedString)
    }

    @MainActor
    func makeAttributedString() -> NSAttributedString {
        NSAttributedString(attributedString: storage)
    }
}
