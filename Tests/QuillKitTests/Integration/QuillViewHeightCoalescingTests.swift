@testable import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Height Coalescing", .serialized, GloballySerialized(), .tags(.integration, .rendering))
struct QuillViewHeightCoalescingTests {
    @Test("Rapid updates coalesce into one height notification per burst")
    func rapidUpdatesCoalesceHeightCallbacks() async {
        let heightSleepController = ControlledSleepController()
        let schedulerTimeController = TestTimeController()
        var measuredHeight: CGFloat = 0
        let renderConfiguration = RenderConfiguration(
            streamingMode: .smoothedTail,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.05),
            bufferedStream: .default
        )
        let configuration = QuillConfiguration(
            streaming: .init(mode: .smoothedTail, preset: .balanced),
            renderConfiguration: renderConfiguration
        )
        let view = makeHeightCoalescingQuillView(
            configuration: configuration,
            renderConfiguration: renderConfiguration,
            heightSleepController: heightSleepController,
            schedulerTimeController: schedulerTimeController,
            measuredHeight: { measuredHeight }
        )
        await primeInitialMeasurement(
            for: view,
            heightSleepController: heightSleepController
        )
        var callbackCount = 0
        view.onHeightChange = { _, _ in
            callbackCount += 1
        }

        for lineCount in 1...6 {
            measuredHeight = CGFloat(lineCount) * 40
            let markdown = Array(repeating: "line", count: lineCount).joined(separator: "\n\n")
            view.markdown = markdown
        }
        view.layoutIfNeeded()

        let firstBurstScheduled = await eventually(timeout: .milliseconds(100)) {
            heightSleepController.requestCount == 2
        }
        #expect(firstBurstScheduled)

        heightSleepController.resumeNext()
        let firstBurstCompleted = await eventually(timeout: .milliseconds(100)) {
            heightSleepController.completedSleepCount == 2
        }
        #expect(firstBurstCompleted)

        let firstNotificationArrived = await eventually(timeout: .milliseconds(100)) {
            callbackCount == 1
        }
        #expect(firstNotificationArrived)

        measuredHeight = 480
        view.markdown = Array(repeating: "expanded", count: 12).joined(separator: "\n\n")
        view.layoutIfNeeded()

        let secondBurstScheduled = await eventually(timeout: .milliseconds(100)) {
            heightSleepController.requestCount == 3
        }
        #expect(secondBurstScheduled)

        heightSleepController.resumeNext()
        let secondBurstCompleted = await eventually(timeout: .milliseconds(100)) {
            heightSleepController.completedSleepCount == 3
        }
        #expect(secondBurstCompleted)

        let secondNotificationArrived = await eventually(timeout: .milliseconds(100)) {
            callbackCount == 2
        }
        #expect(secondNotificationArrived)
    }

    @Test("Reapplying identical markdown does not emit a second height callback")
    func identicalMarkdownSkipsRedundantHeightCallback() async {
        let heightSleepController = ControlledSleepController()
        let schedulerTimeController = TestTimeController()
        var measuredHeight: CGFloat = 0
        let renderConfiguration = RenderConfiguration(
            streamingMode: .smoothedTail,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.05),
            bufferedStream: .default
        )
        let configuration = QuillConfiguration(
            streaming: .init(mode: .smoothedTail, preset: .balanced),
            renderConfiguration: renderConfiguration
        )
        let view = makeHeightCoalescingQuillView(
            configuration: configuration,
            renderConfiguration: renderConfiguration,
            heightSleepController: heightSleepController,
            schedulerTimeController: schedulerTimeController,
            measuredHeight: { measuredHeight }
        )
        await primeInitialMeasurement(
            for: view,
            heightSleepController: heightSleepController
        )
        var callbackCount = 0
        view.onHeightChange = { _, _ in
            callbackCount += 1
        }

        measuredHeight = 160
        let markdown = Array(repeating: "line", count: 4).joined(separator: "\n\n")
        view.markdown = markdown
        view.layoutIfNeeded()

        let firstRenderScheduled = await eventually(timeout: .milliseconds(100)) {
            heightSleepController.requestCount == 2
        }
        #expect(firstRenderScheduled)

        heightSleepController.resumeNext()
        let firstRenderCompleted = await eventually(timeout: .milliseconds(100)) {
            heightSleepController.completedSleepCount == 2
        }
        #expect(firstRenderCompleted)

        let firstNotificationArrived = await eventually(timeout: .milliseconds(100)) {
            callbackCount == 1
        }
        #expect(firstNotificationArrived)

        let initialSleepCount = heightSleepController.requestCount
        let initialContentRevision = view.firstDocumentTextView()?.contentRevision

        measuredHeight = 320
        view.markdown = markdown
        view.layoutIfNeeded()
        await Task.yield()

        #expect(heightSleepController.requestCount == initialSleepCount)
        #expect(view.firstDocumentTextView()?.contentRevision == initialContentRevision)
        #expect(callbackCount == 1)
    }
}

private extension QuillViewHeightCoalescingTests {
    func primeInitialMeasurement(
        for view: QuillView,
        heightSleepController: ControlledSleepController
    ) async {
        view.layoutIfNeeded()

        let initialMeasurementScheduled = await eventually(timeout: .milliseconds(100)) {
            heightSleepController.requestCount == 1
        }
        #expect(initialMeasurementScheduled)

        heightSleepController.resumeNext()
        let initialMeasurementFinished = await eventually(timeout: .milliseconds(100)) {
            heightSleepController.completedSleepCount == 1
        }
        #expect(initialMeasurementFinished)
    }

    func makeHeightCoalescingQuillView(
        configuration: QuillConfiguration,
        renderConfiguration: RenderConfiguration,
        heightSleepController: ControlledSleepController,
        schedulerTimeController: TestTimeController,
        measuredHeight: @escaping () -> CGFloat
    ) -> QuillView {
        let renderer = makeDocumentRenderer()
        let scheduler = BufferedStreamCommitScheduler(
            moduleStreamGate: .init(),
            now: { schedulerTimeController.now() },
            sleep: { duration in
                await schedulerTimeController.sleep(for: duration)
            }
        )
        let dependencies = QuillView.Dependencies(
            heightCoordinator: HeightCoordinator(
                sleep: { duration in
                    await heightSleepController.sleep(for: duration)
                },
                measureHeight: { _ in
                    measuredHeight()
                }
            ),
            markdownParser: .live,
            streamCoordinator: StreamCoordinator(
                renderer: renderer,
                renderConfiguration: renderConfiguration,
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
        return view
    }
}
