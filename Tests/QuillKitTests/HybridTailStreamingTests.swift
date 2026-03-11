@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("Hybrid Tail Streaming")
struct HybridTailStreamingTests {
    @Test("Tail preview appears before paragraph freeze and commits without duplication")
    func tailAppearsBeforeFreeze() async throws {
        let view = makeQuillView(mode: .hybridTail)

        view.append("Hello ")
        await wait(milliseconds: 30)

        let stack = try #require(stackView(for: view))
        #expect(stack.arrangedSubviews.isEmpty)

        view.append("hybrid tail\n")
        await wait(milliseconds: 50)

        #expect(stack.arrangedSubviews.count == 1)
        let tailPreviewView = try #require(stack.arrangedSubviews.first)
        #expect(tailPreviewView is TextFlowView)

        view.append("still typing\n")
        await wait(milliseconds: 50)
        #expect(stack.arrangedSubviews.count == 1)

        view.append("\n")
        await wait(milliseconds: 160)

        #expect(stack.arrangedSubviews.count == 1)
        #expect(stack.arrangedSubviews[0] === tailPreviewView)
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

    func stackView(for view: QuillView) -> UIStackView? {
        view.subviews.first { $0 is UIStackView } as? UIStackView
    }

    func wait(milliseconds: UInt64) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}
