@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("Hybrid Tail Streaming")
struct HybridTailStreamingTests {
    @Test("Tail preview appears before paragraph freeze and commits without duplication")
    func tailAppearsBeforeFreeze() async throws {
        let view = makeQuillView(mode: .hybridTail)
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
        let remainsSingleDuringTailUpdate = await eventually(timeout: .seconds(1.2)) {
            container.blockViews.count == 1
                && container.blockViews.first === tailPreviewView
        }
        #expect(remainsSingleDuringTailUpdate)

        view.append("\n")
        let promotedWithoutDuplication = await eventually(timeout: .seconds(1.2)) {
            container.blockViews.count == 1
                && container.blockViews.first === tailPreviewView
        }
        #expect(promotedWithoutDuplication)
        #expect(view.currentMarkdown == "Hello hybrid tail\nstill typing\n\n")
    }
}

private extension HybridTailStreamingTests {
    func makeQuillView(mode: StreamingMode) -> QuillView {
        let configuration = QuillRenderConfiguration(
            streamingMode: mode,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.005),
            tail: .default
        )

        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0), internalConfiguration: configuration)
        view.layoutIfNeeded()
        return view
    }

    func containerView(for view: QuillView) -> BlockContainerView? {
        view.subviews.first { $0 is BlockContainerView } as? BlockContainerView
    }

    func eventually(
        timeout: Duration = .milliseconds(800),
        poll: Duration = .milliseconds(10),
        _ condition: () -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while clock.now < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(for: poll)
        }

        return condition()
    }
}
