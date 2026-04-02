@testable import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Height Coalescing", .tags(.integration, .rendering))
struct QuillViewHeightCoalescingTests {
    private static let coalescingWindowLowerBound: TimeInterval = 0.045

    @Test("Rapid updates coalesce into one height notification per scheduler window")
    func rapidUpdatesCoalesceHeightCallbacks() async throws {
        let timeController = TestTimeController()
        let configuration = RenderConfiguration(
            streamingMode: .smoothedTail,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.05),
            bufferedStream: .default
        )
        let view = makeHeightCoalescingQuillView(
            configuration: configuration,
            timeController: timeController
        )
        var callbackTimes: [TimeInterval] = []
        view.onHeightChange = { _, _ in
            callbackTimes.append(timeController.now())
        }

        for lineCount in 1...6 {
            let markdown = Array(repeating: "line", count: lineCount).joined(separator: "\n\n")
            view.markdown = markdown
        }

        let firstNotificationArrived = await eventually(timeout: .milliseconds(100)) {
            callbackTimes.count == 1
        }
        #expect(firstNotificationArrived)

        view.markdown = Array(repeating: "expanded", count: 12).joined(separator: "\n\n")
        let secondNotificationArrived = await eventually(timeout: .milliseconds(100)) {
            callbackTimes.count == 2
        }
        #expect(secondNotificationArrived)

        let firstCallback = try #require(callbackTimes.first)
        let secondCallback = try #require(callbackTimes.last)
        let callbackDelta = secondCallback - firstCallback
        #expect(callbackDelta >= Self.coalescingWindowLowerBound)
    }
}

private extension QuillViewHeightCoalescingTests {
    func makeHeightCoalescingQuillView(
        configuration: RenderConfiguration,
        timeController: TestTimeController
    ) -> QuillView {
        let renderer = makeDocumentRenderer()
        let scheduler = BufferedStreamCommitScheduler(
            moduleStreamGate: .init(),
            now: { timeController.now() },
            sleep: { duration in
                await timeController.sleep(for: duration)
            }
        )
        let dependencies = QuillView.Dependencies(
            heightCoordinator: HeightCoordinator(sleep: { duration in
                await timeController.sleep(for: duration)
            }),
            markdownParser: .live,
            streamCoordinator: StreamCoordinator(
                renderer: renderer,
                renderConfiguration: configuration,
                bufferedStreamCommitScheduler: scheduler,
                bufferedVisualFeeder: .init(),
                streamController: MarkdownStreamController.init
            )
        )

        let view = QuillView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 0),
            configuration: configuration,
            dependencies: dependencies
        )
        view.layoutIfNeeded()
        return view
    }
}
