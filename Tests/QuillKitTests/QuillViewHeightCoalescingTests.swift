@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("QuillView Height Coalescing")
struct QuillViewHeightCoalescingTests {
    @Test("Rapid updates coalesce into one height notification per scheduler window")
    func coalescesHeightUpdates() async {
        let configuration = QuillRenderConfiguration(
            streamingMode: .stableBlocks,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.05),
            tail: .default
        )

        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0), internalConfiguration: configuration)

        var callbackTimes: [Date] = []
        view.onHeightChange = { _, _ in
            callbackTimes.append(Date())
        }

        for lineCount in 1...6 {
            let markdown = Array(repeating: "line", count: lineCount).joined(separator: "\n\n")
            view.markdown = markdown
        }

        await wait(milliseconds: 140)
        #expect(callbackTimes.count <= 1)

        view.markdown = Array(repeating: "expanded", count: 12).joined(separator: "\n\n")
        await wait(milliseconds: 140)

        #expect(callbackTimes.count >= 1)
        #expect(callbackTimes.count <= 2)

        if callbackTimes.count == 2 {
            let delta = callbackTimes[1].timeIntervalSince(callbackTimes[0])
            #expect(delta >= 0.045)
        }
    }
}

private extension QuillViewHeightCoalescingTests {
    func wait(milliseconds: UInt64) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}
