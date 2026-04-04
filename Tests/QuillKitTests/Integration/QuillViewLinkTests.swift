@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Links", .tags(.integration))
struct QuillViewLinkTests {
    @Test("onLinkSelection callback receives URL from static render")
    func onLinkSelectionReceivesURLFromStaticRender() async throws {
        let view = makeSmoothedTailQuillView()
        var tappedURL: URL?

        view.onLinkSelection = { url in
            tappedURL = url
        }
        view.markdown = "[click](https://example.com)"

        let rendered = await eventually {
            view.hasDocumentContent
        }
        #expect(rendered)

        let textView = try #require(view.firstDocumentTextView())
        textView.layoutIfNeeded()

        #expect(view.onLinkSelection != nil)
        #expect(tappedURL == nil)
    }

    @Test("onLinkSelection callback is re-assigned without crash")
    func onLinkSelectionCallbackReassignment() {
        let view = makeSmoothedTailQuillView()

        var firstURL: URL?
        view.onLinkSelection = { url in firstURL = url }

        var secondURL: URL?
        view.onLinkSelection = { url in secondURL = url }

        #expect(firstURL == nil)
        #expect(secondURL == nil)
    }
}
