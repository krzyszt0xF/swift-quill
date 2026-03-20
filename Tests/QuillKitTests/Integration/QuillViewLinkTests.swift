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
