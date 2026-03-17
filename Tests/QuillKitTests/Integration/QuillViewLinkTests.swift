@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Links")
struct QuillViewLinkTests {
    @Test("static render rebinds existing flow views when handler changes")
    func staticRenderRebindsExistingFlowViews() async throws {
        let view = makeStableBlocksQuillView()
        view.markdown = "[click](https://example.com)"

        let laidOut = await eventually {
            guard let flow = findSubview(of: TextFlowView.self, in: view) else { return false }
            return checkFlowViewIsLaidOut(flow, in: view)
        }
        #expect(laidOut)

        var tappedURL: URL?
        view.onLinkTap = { url in
            tappedURL = url
        }

        let textFlowView = try #require(findSubview(of: TextFlowView.self, in: view))
        textFlowView.handleTap(at: makeTapPoint(in: textFlowView, rootView: view))

        #expect(tappedURL == URL(string: "https://example.com"))
    }

    @Test("streaming tail link is tappable before promotion and after promotion")
    func streamingTailLinkStaysTappableAcrossPromotion() async throws {
        let view = makeHybridTailQuillView()
        var tappedURLs: [URL] = []

        view.onLinkTap = { url in
            tappedURLs.append(url)
        }

        view.append("[click](https://example.com)\n")

        let tailRendered = await eventually {
            guard let container = containerView(for: view) else { return false }
            guard let flow = container.blockViews.first(where: { $0 is TextFlowView }) as? TextFlowView else { return false }
            return checkFlowViewIsLaidOut(flow, in: view)
        }
        #expect(tailRendered)

        let initialFlowView = try #require(containerView(for: view)?.blockViews.first as? TextFlowView)
        initialFlowView.handleTap(at: makeTapPoint(in: initialFlowView, rootView: view))

        view.append("\n\nNext paragraph\n")

        let promoted = await eventually {
            guard let container = containerView(for: view) else { return false }
            return container.blockViews.contains(where: { $0 === initialFlowView }) && container.blockViews.count >= 2
        }
        #expect(promoted)

        initialFlowView.handleTap(at: makeTapPoint(in: initialFlowView, rootView: view))

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
            guard let flow = findSubview(of: TextFlowView.self, in: view) else { return false }
            return checkFlowViewIsLaidOut(flow, in: view)
        }
        #expect(initialRender)

        view.markdown = "## [second](https://two.example)"

        let rerendered = await eventually {
            guard let flow = findSubview(of: TextFlowView.self, in: view) else { return false }
            return checkFlowViewIsLaidOut(flow, in: view)
        }
        #expect(rerendered)

        let textFlowView = try #require(findSubview(of: TextFlowView.self, in: view))
        textFlowView.handleTap(at: makeTapPoint(in: textFlowView, rootView: view))

        #expect(tappedURL == URL(string: "https://two.example"))
    }
}

private extension QuillViewLinkTests {
    func checkFlowViewIsLaidOut(_ flow: TextFlowView, in rootView: QuillView) -> Bool {
        rootView.layoutIfNeeded()
        flow.layoutIfNeeded()
        return flow.bounds.width > 0 && flow.bounds.height > 0
    }

    func makeTapPoint(in flow: TextFlowView, rootView: QuillView) -> CGPoint {
        rootView.layoutIfNeeded()
        flow.layoutIfNeeded()
        return CGPoint(x: 8, y: max(1, flow.bounds.height / 2))
    }
}
