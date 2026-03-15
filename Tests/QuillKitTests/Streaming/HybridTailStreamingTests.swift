@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Hybrid Tail Streaming")
struct HybridTailStreamingTests {
    @Test("Tail preview appears before paragraph freeze and commits without duplication")
    func tailPreviewAppearsBeforeFreeze() async throws {
        let view = makeHybridTailQuillView()
        let container = try #require(containerView(for: view))

        #expect(container.blockViews.isEmpty)

        view.append("Hello hybrid tail\n")
        let previewAppeared = await eventually(timeout: .seconds(1.2)) {
            container.blockViews.count == 1
                && container.blockViews.first is TextFlowView
        }
        #expect(previewAppeared)

        let tailPreviewView = try #require(container.blockViews.first)

        view.append("still typing\n")
        let tailPreviewRemainedSingleView = await eventually(timeout: .seconds(1.2)) {
            container.blockViews.count == 1
                && container.blockViews.first === tailPreviewView
        }
        #expect(tailPreviewRemainedSingleView)

        view.append("\n")
        let tailPromotionAvoidedDuplication = await eventually(timeout: .seconds(1.2)) {
            container.blockViews.count == 1
                && container.blockViews.first === tailPreviewView
        }
        #expect(tailPromotionAvoidedDuplication)
        #expect(view.currentMarkdown == "Hello hybrid tail\nstill typing\n\n")
    }
}
