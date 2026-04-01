@testable import QuillKit
@testable import QuillSwiftUI
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite("QuillMarkdownView")
struct QuillMarkdownViewTests {
    @Test("fittedSize falls back to runtime width when proposed width is zero")
    func fittedSizeFallsBackForZeroWidth() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: 0, height: nil)
        let result = view.calculateFittedSize(for: proposal)
        let expectedWidth = expectedFallbackWidth(for: view)

        #expect(result?.width == expectedWidth)
        #expect(result?.width.isFinite == true)
    }

    @Test("fittedSize falls back to runtime width when proposed width is negative")
    func fittedSizeFallsBackForNegativeWidth() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: -10, height: nil)
        let result = view.calculateFittedSize(for: proposal)
        let expectedWidth = expectedFallbackWidth(for: view)

        #expect(result?.width == expectedWidth)
        #expect(result?.width.isFinite == true)
    }

    @Test("fittedSize returns proposed width as output width")
    func fittedSizeReturnsProposedWidth() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: 320, height: nil)
        let result = view.calculateFittedSize(for: proposal)
        #expect(result?.width == 320)
    }

    @Test("fittedSize returns height >= 1 for empty content")
    func fittedSizeReturnsMinimumHeight() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: 320, height: nil)
        let result = view.calculateFittedSize(for: proposal)
        #expect(result != nil)
        if let result { #expect(result.height >= 1) }
    }

    @Test("fittedSize falls back to runtime width when proposed width is infinite")
    func fittedSizeFallsBackForInfiniteWidth() {
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 280, height: 0))
        let proposal = ProposedViewSize(width: .infinity, height: nil)
        let result = view.calculateFittedSize(for: proposal)
        let expectedWidth = expectedFallbackWidth(for: view)

        #expect(result?.width == expectedWidth)
        #expect(result?.width.isFinite == true)
    }

    @Test("fittedSize falls back to a finite width when proposed width is nan")
    func fittedSizeFallsBackForNaNWidth() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: .nan, height: nil)
        let result = view.calculateFittedSize(for: proposal)

        #expect(result != nil)
        #expect(result?.width.isFinite == true)
        if let result {
            #expect(result.width == expectedFallbackWidth(for: view))
        }
    }

    @Test("fittedSize prefers bounds width when it exceeds screen width")
    func fittedSizePrefersLargerBoundsWidth() {
        let screenWidth = UIScreen.main.bounds.width
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: screenWidth + 64, height: 0))
        let result = view.calculateFittedSize(for: ProposedViewSize(width: .infinity, height: nil))

        #expect(result?.width == screenWidth + 64)
        #expect(result?.width.isFinite == true)
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

private extension QuillMarkdownViewTests {
    func expectedFallbackWidth(for view: QuillView) -> CGFloat {
        let screenWidth = view.window?.screen.bounds.width ?? UIScreen.main.bounds.width
        return max(view.bounds.width, screenWidth)
    }
}
