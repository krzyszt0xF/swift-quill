@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Links")
struct QuillViewLinkTests {
    @Test("onLinkSelection callback receives URL from static render")
    func onLinkSelectionReceivesURLFromStaticRender() async throws {
        let view = makeStableBlocksQuillView()
        var tappedURL: URL?

        view.onLinkSelection = { url in
            tappedURL = url
        }
        view.markdown = "[click](https://example.com)"

        let rendered = await eventually {
            documentHasContent(view)
        }
        #expect(rendered)

        guard let textView = documentTextView(for: view) else {
            Issue.record("Expected DocumentTextView in QuillView")
            return
        }
        textView.layoutIfNeeded()

        #expect(view.onLinkSelection != nil)
        #expect(tappedURL == nil)
    }

    @Test("onLinkSelection callback is re-assigned without crash")
    func onLinkSelectionCallbackReassignment() {
        let view = makeStableBlocksQuillView()

        var firstURL: URL?
        view.onLinkSelection = { url in firstURL = url }

        var secondURL: URL?
        view.onLinkSelection = { url in secondURL = url }

        #expect(firstURL == nil)
        #expect(secondURL == nil)
    }
}
