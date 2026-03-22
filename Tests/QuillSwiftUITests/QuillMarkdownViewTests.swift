@testable import QuillKit
@testable import QuillSwiftUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite("QuillMarkdownView")
struct QuillMarkdownViewTests {
    @Test("fittedSize returns nil when proposed width is zero")
    func fittedSizeReturnsNilForZeroWidth() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: 0, height: nil)
        let result = fittedSize(for: view, proposal: proposal)
        #expect(result == nil)
    }

    @Test("fittedSize returns nil when proposed width is negative")
    func fittedSizeReturnsNilForNegativeWidth() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: -10, height: nil)
        let result = fittedSize(for: view, proposal: proposal)
        #expect(result == nil)
    }

    @Test("fittedSize returns proposed width as output width")
    func fittedSizeReturnsProposedWidth() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: 320, height: nil)
        let result = fittedSize(for: view, proposal: proposal)
        #expect(result?.width == 320)
    }

    @Test("fittedSize returns height >= 1 for empty content")
    func fittedSizeReturnsMinimumHeight() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: 320, height: nil)
        let result = fittedSize(for: view, proposal: proposal)
        #expect(result != nil)
        if let result { #expect(result.height >= 1) }
    }

    @Test("QuillView.markdown setter triggers static render")
    func markdownSetterTriggersRender() {
        let view = QuillView()
        view.markdown = "# Hello"
        #expect(view.markdown == "# Hello")
        #expect(view.currentMarkdown == "# Hello")
    }

    @Test("QuillView.markdown preserves state on same value re-set")
    func markdownPreservesStateOnSameValue() {
        let view = QuillView()
        view.markdown = "# Same"
        #expect(view.currentMarkdown == "# Same")

        view.markdown = "# Same"
        #expect(view.currentMarkdown == "# Same")
    }

    @Test("QuillView.markdown updates when value differs")
    func markdownUpdatesWhenDifferent() {
        let view = QuillView()
        view.markdown = "# First"
        #expect(view.currentMarkdown == "# First")

        view.markdown = "# Second"
        #expect(view.currentMarkdown == "# Second")
    }

    @Test("empty markdown does not crash")
    func emptyMarkdownPreservesEmptyState() {
        let view = QuillView()
        view.markdown = ""
        #expect(view.markdown == "")
        #expect(view.currentMarkdown == "")
    }

    @Test("onQuillLinkTap stores handler and applies it to QuillView")
    func linkTapModifierAppliesHandler() {
        var tappedURL: URL?
        let markdownView = QuillMarkdownView(markdown: "[click](https://example.com)").onQuillLinkTap { url in
            tappedURL = url
        }
        let view = QuillView()

        markdownView.applyConfiguration(to: view)
        view.onLinkSelection?(URL(string: "https://example.com")!)

        #expect(markdownView.linkTapHandler != nil)
        #expect(tappedURL == URL(string: "https://example.com"))
    }
}
