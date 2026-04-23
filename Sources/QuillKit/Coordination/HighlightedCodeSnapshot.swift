import UIKit

// @unchecked Sendable: NSAttributedString is not Sendable. The snapshot stores a defensive immutable copy
// at init and hands back fresh copies to main-actor callers via makeAttributedString(); the stored reference
// is never mutated and never shared directly.
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
