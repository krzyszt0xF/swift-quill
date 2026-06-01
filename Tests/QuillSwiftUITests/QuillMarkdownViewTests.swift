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
        #expect(view.accumulatedMarkdown == "# Hello")
    }

    @Test("QuillView.markdown preserves state on same value re-set")
    func markdownPreservesStateOnSameValue() {
        let view = QuillView()
        view.markdown = "# Same"
        #expect(view.accumulatedMarkdown == "# Same")

        view.markdown = "# Same"
        #expect(view.accumulatedMarkdown == "# Same")
    }

    @Test("QuillView.markdown updates when value differs")
    func markdownUpdatesWhenDifferent() {
        let view = QuillView()
        view.markdown = "# First"
        #expect(view.accumulatedMarkdown == "# First")

        view.markdown = "# Second"
        #expect(view.accumulatedMarkdown == "# Second")
    }

    @Test("empty markdown does not crash")
    func emptyMarkdownPreservesEmptyState() {
        let view = QuillView()
        view.markdown = ""
        #expect(view.markdown?.isEmpty == true)
        #expect(view.accumulatedMarkdown?.isEmpty == true)
    }

    @Test("applyConfiguration wires link tap handler to QuillView")
    func linkTapHandlerAppliedToView() {
        var tappedURL: URL?
        let markdownView = QuillMarkdownView(markdown: "[click](https://example.com)")
        let view = QuillView()

        markdownView.applyConfiguration(
            to: view,
            linkTapHandler: { url in tappedURL = url }
        )
        view.onLinkSelection?(URL(string: "https://example.com")!)

        #expect(tappedURL == URL(string: "https://example.com"))
    }

    @Test("static markdown reports its expanded content height synchronously (Issue 01)")
    func staticMarkdownReportsHonestFittedHeightSynchronously() {
        let proposal = ProposedViewSize(width: 320, height: nil)

        func fittedHeight(forMarkdown markdown: String?) -> CGFloat {
            let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
            if let markdown {
                QuillMarkdownView(markdown: markdown).applyConfiguration(to: view)
            }
            return view.calculateFittedSize(for: proposal)?.height ?? 0
        }

        let multiLine = (1...8).map { "Paragraph number \($0)." }.joined(separator: "\n\n")

        let emptyHeight = fittedHeight(forMarkdown: nil)
        let oneLineHeight = fittedHeight(forMarkdown: "Single line of content.")
        let multiLineHeight = fittedHeight(forMarkdown: multiLine)

        #expect(oneLineHeight > emptyHeight)
        #expect(multiLineHeight > oneLineHeight)
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
