@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Links")
struct QuillViewLinkTests {
    @Test("static render rebinds existing flow views when handler changes")
    func staticRenderRebindsExistingFlowViews() async {
        let view = makeStableBlocksQuillView()
        view.markdown = "[click](https://example.com)"

        let rendered = await eventually {
            findSubview(of: TextFlowView.self, in: view) != nil
        }
        #expect(rendered)

        var tappedURL: URL?
        view.onLinkTap = { url in
            tappedURL = url
        }

        let textFlowView = try #require(findSubview(of: TextFlowView.self, in: view))
        textFlowView.handleTap(at: CGPoint(x: 8, y: max(1, textFlowView.intrinsicContentSize.height / 2)))

        #expect(tappedURL == URL(string: "https://example.com"))
    }

    @Test("streaming tail link is tappable before promotion and after promotion")
    func streamingTailLinkStaysTappableAcrossPromotion() async throws {
        let view = makeHybridTailQuillView()
        var tappedURLs: [URL] = []

        view.onLinkTap = { url in
            tappedURLs.append(url)
        }

        view.append("[click](https://example.com)")

        let tailRendered = await eventually {
            containerView(for: view)?.blockViews.contains(where: { $0 is TextFlowView }) == true
        }
        #expect(tailRendered)

        let initialFlowView = try #require(containerView(for: view)?.blockViews.first as? TextFlowView)
        initialFlowView.handleTap(at: CGPoint(x: 8, y: max(1, initialFlowView.intrinsicContentSize.height / 2)))

        view.append("\n\nNext paragraph")

        let promoted = await eventually {
            guard let container = containerView(for: view) else { return false }
            return container.blockViews.contains(where: { $0 === initialFlowView }) && container.blockViews.count >= 2
        }
        #expect(promoted)

        initialFlowView.handleTap(at: CGPoint(x: 8, y: max(1, initialFlowView.intrinsicContentSize.height / 2)))

        #expect(tappedURLs == [
            URL(string: "https://example.com"),
            URL(string: "https://example.com"),
        ].compactMap { $0 })
    }

    @Test("replacement flow views inherit current handler")
    func replacementFlowViewsInheritCurrentHandler() async throws {
        let view = makeStableBlocksQuillView()
        var tappedURL: URL?

        view.onLinkTap = { url in
            tappedURL = url
        }
        view.markdown = "[first](https://one.example)"

        let initialRender = await eventually {
            findSubview(of: TextFlowView.self, in: view) != nil
        }
        #expect(initialRender)

        view.markdown = "## [second](https://two.example)"

        let rerendered = await eventually {
            findSubview(of: TextFlowView.self, in: view) != nil
        }
        #expect(rerendered)

        let textFlowView = try #require(findSubview(of: TextFlowView.self, in: view))
        textFlowView.handleTap(at: CGPoint(x: 8, y: max(1, textFlowView.intrinsicContentSize.height / 2)))

        #expect(tappedURL == URL(string: "https://two.example"))
    }
}
