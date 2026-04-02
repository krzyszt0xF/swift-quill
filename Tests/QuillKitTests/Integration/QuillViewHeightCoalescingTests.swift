@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Height Coalescing", .tags(.integration, .rendering))
struct QuillViewHeightCoalescingTests {
    private static let coalescingWindowLowerBound: Duration = .milliseconds(45)

    @Test("Rapid updates coalesce into one height notification per scheduler window")
    func rapidUpdatesCoalesceHeightCallbacks() async throws {
        let configuration = RenderConfiguration(
            streamingMode: .smoothedTail,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.05),
            bufferedStream: .default
        )

        let view = QuillView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 0),
            configuration: configuration,
            dependencies: .live
        )

        let clock = ContinuousClock()
        var callbackTimes: [ContinuousClock.Instant] = []
        view.onHeightChange = { _, _ in
            callbackTimes.append(clock.now)
        }

        for lineCount in 1...6 {
            let markdown = Array(repeating: "line", count: lineCount).joined(separator: "\n\n")
            view.markdown = markdown
        }

        let firstNotificationArrived = await eventually(timeout: .milliseconds(140)) {
            callbackTimes.count == 1
        }
        #expect(firstNotificationArrived)

        view.markdown = Array(repeating: "expanded", count: 12).joined(separator: "\n\n")
        let secondNotificationArrived = await eventually(timeout: .milliseconds(140)) {
            callbackTimes.count == 2
        }
        #expect(secondNotificationArrived)

        let firstCallback = try #require(callbackTimes.first)
        let secondCallback = try #require(callbackTimes.last)
        let callbackDelta = firstCallback.duration(to: secondCallback)
        #expect(callbackDelta >= Self.coalescingWindowLowerBound)
    }
}
