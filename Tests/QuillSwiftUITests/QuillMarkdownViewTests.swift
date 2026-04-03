@testable import QuillKit
@testable import QuillSwiftUI
import QuillSharedTestSupport
import SwiftUI
import Testing
import UIKit

@MainActor
@Suite("QuillMarkdownView", .tags(.rendering))
struct QuillMarkdownViewTests {
    /*(Sendable)*/ nonisolated static let fallbackWidthCases: [FallbackWidthTestCase] = [
        .init(name: "Infinite width", proposedWidth: .infinity, viewWidth: 280),
        .init(name: "NaN width", proposedWidth: .nan, viewWidth: nil),
        .init(name: "Negative width", proposedWidth: -10, viewWidth: nil),
        .init(name: "Zero width", proposedWidth: 0, viewWidth: nil),
    ]

    @Test("fittedSize falls back to runtime width for invalid proposals", arguments: fallbackWidthCases)
    func fittedSizeFallsBackForInvalidWidth(_ testCase: FallbackWidthTestCase) {
        let viewWidth = CGFloat(testCase.viewWidth ?? 0)
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: viewWidth, height: 0))
        let proposal = ProposedViewSize(width: CGFloat(testCase.proposedWidth), height: nil)
        let result = view.calculateFittedSize(for: proposal)
        let expectedWidth = expectedFallbackWidth(for: view)

        #expect(result?.width == expectedWidth)
        #expect(result?.width.isFinite == true)
    }

    @Test("fittedSize returns height >= 1 for empty content")
    func fittedSizeReturnsMinimumHeight() throws {
        let view = QuillView()
        let proposal = ProposedViewSize(width: 320, height: nil)
        let result = try #require(view.calculateFittedSize(for: proposal))
        #expect(result.height >= 1)
    }

    @Test("fittedSize returns proposed width as output width")
    func fittedSizeReturnsProposedWidth() {
        let view = QuillView()
        let proposal = ProposedViewSize(width: 320, height: nil)
        let result = view.calculateFittedSize(for: proposal)
        #expect(result?.width == 320)
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
        #expect(view.markdown.isEmpty)
        #expect(view.currentMarkdown.isEmpty)
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

struct FallbackWidthTestCase: Sendable {
    let name: String
    let proposedWidth: Double
    let viewWidth: Double?
}

extension FallbackWidthTestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}

private extension QuillMarkdownViewTests {
    func expectedFallbackWidth(for view: QuillView) -> CGFloat {
        let screenWidth = view.window?.screen.bounds.width ?? UIScreen.main.bounds.width
        return max(view.bounds.width, screenWidth)
    }
}
