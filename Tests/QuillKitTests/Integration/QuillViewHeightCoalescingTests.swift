@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Height Coalescing")
struct QuillViewHeightCoalescingTests {
    private static let coalescingWindowLowerBound: TimeInterval = 0.045

    @Test("Rapid updates coalesce into one height notification per scheduler window")
    func rapidUpdatesCoalesceHeightCallbacks() async {
        let configuration = RenderConfiguration(
            streamingMode: .stableBlocks,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.05)
        )

        let view = QuillView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 0),
            configuration: configuration,
            dependencies: .live
        )

        var callbackTimes: [Date] = []
        view.onHeightChange = { _, _ in
            callbackTimes.append(Date())
        }

        for lineCount in 1...6 {
            let markdown = Array(repeating: "line", count: lineCount).joined(separator: "\n\n")
            view.markdown = markdown
        }

        await wait(for: .milliseconds(140))
        #expect(callbackTimes.count <= 1)

        view.markdown = Array(repeating: "expanded", count: 12).joined(separator: "\n\n")
        await wait(for: .milliseconds(140))

        #expect(callbackTimes.count >= 1)
        #expect(callbackTimes.count <= 2)

        if callbackTimes.count == 2 {
            let callbackDelta = callbackTimes[1].timeIntervalSince(callbackTimes[0])
            #expect(callbackDelta >= Self.coalescingWindowLowerBound)
        }
    }
}
