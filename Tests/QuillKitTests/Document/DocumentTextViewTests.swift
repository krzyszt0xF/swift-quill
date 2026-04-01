@testable import QuillKit
import QuillCore
import Testing
import UIKit

@MainActor
@Suite("DocumentTextView")
struct DocumentTextViewTests {
    @Test("Text drag interaction is disabled")
    func textDragInteractionIsDisabled() {
        let textView = DocumentTextView()

        #expect(textView.textDragInteraction?.isEnabled == false)
    }

    @Test("Link selection callback overrides default interaction when installed")
    func linkSelectionCallbackOverridesDefaultInteraction() {
        let textView = DocumentTextView()
        let url = URL(string: "https://example.com")!
        var selectedURL: URL?
        textView.onLinkSelection = { selectedURL = $0 }

        let shouldInteract = textView.handleLinkSelection(url)

        #expect(shouldInteract == false)
        #expect(selectedURL == url)
    }
}
