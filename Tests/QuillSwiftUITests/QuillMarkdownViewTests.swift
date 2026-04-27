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

    @Test(
        "stacked static markdown views expand to their rendered content height",
        .disabled("flaky under full bundle load; passes in isolation; tracked for follow-up")
    )
    func stackedStaticMarkdownViewsExpand() async throws {
        let markdown = """
        This is a fairly long paragraph that should wrap across several lines when rendered at
        a typical mobile width. The content needs enough length to prove each bubble expands
        after the asynchronous static render completes, instead of collapsing to a single line.
        """
        let host = UIHostingController(
            rootView: VStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    QuillMarkdownView(markdown: markdown)
                }
            }
            .frame(width: 375, height: 800, alignment: .topLeading)
        )

        host.loadViewIfNeeded()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.bounds = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let rendered = await eventually {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()

            let quillViews = host.view.allSubviews(of: QuillView.self)
            guard quillViews.count == 3 else { return false }

            return quillViews.allSatisfy { quillView in
                guard
                    let textView = quillView.firstSubview(of: DocumentTextView.self),
                    let attributedString = textView.contentStorage?.attributedString
                else {
                    return false
                }

                return attributedString.length > 0
            }
        }
        #expect(rendered)

        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()

        let quillViews = host.view
            .allSubviews(of: QuillView.self)
            .sorted {
                $0.convert($0.bounds, to: host.view).minY <
                    $1.convert($1.bounds, to: host.view).minY
            }
        #expect(quillViews.count == 3)

        for quillView in quillViews {
            let textView = try #require(quillView.firstSubview(of: DocumentTextView.self))
            textView.invalidateIntrinsicContentSize()
            let expectedHeight = ceil(textView.intrinsicContentSize.height)

            #expect(quillView.bounds.height >= expectedHeight - 1)
            #expect(quillView.bounds.height > 40)
        }

        for (previous, next) in zip(quillViews, quillViews.dropFirst()) {
            let previousFrame = previous.convert(previous.bounds, to: host.view)
            let nextFrame = next.convert(next.bounds, to: host.view)
            #expect(nextFrame.minY >= previousFrame.maxY)
        }
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

private extension UIView {
    @MainActor
    func allSubviews<T: UIView>(of type: T.Type) -> [T] {
        var matches = subviews.compactMap { $0 as? T }
        for subview in subviews {
            matches += subview.allSubviews(of: type)
        }
        return matches
    }

    @MainActor
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        allSubviews(of: type).first
    }
}
