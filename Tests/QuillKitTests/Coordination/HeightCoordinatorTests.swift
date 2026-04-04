@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("HeightCoordinator", .tags(.rendering))
struct HeightCoordinatorTests {
    private static let coalescingWindow: TimeInterval = 0.05

    @Test("Burst schedules coalesce into one callback")
    func burstSchedulesCoalesceIntoOneCallback() async {
        let sleepController = ControlledSleepController()
        var measuredHeight: CGFloat = 120
        let coordinator = makeHeightCoordinator(
            sleepController: sleepController,
            measuredHeight: { measuredHeight }
        )
        let hostView = makeHostView(width: 320)
        let textView = makeTextView(width: 320)
        var callbackCount = 0

        coordinator.onHeightChange = { _, _ in
            callbackCount += 1
        }

        for revision in 1...3 {
            coordinator.scheduleHeightUpdate(
                hostView: hostView,
                contentRevision: revision,
                documentTextView: textView,
                configuration: makeConfiguration()
            )
        }

        let didSchedule = await eventually(timeout: .milliseconds(100)) {
            sleepController.requestCount == 1
        }

        #expect(didSchedule)
        #expect(callbackCount == 0)

        sleepController.resumeNext()
        let firstWindowCompleted = await eventually(timeout: .milliseconds(100)) {
            sleepController.completedSleepCount == 1
        }
        #expect(firstWindowCompleted)

        let didNotify = await eventually(timeout: .milliseconds(100)) {
            callbackCount == 1
        }

        #expect(didNotify)
        #expect(sleepController.requestCount == 1)
    }

    @Test("Single schedule measures after one coalescing window")
    func singleScheduleMeasuresAfterOneCoalescingWindow() async {
        let sleepController = ControlledSleepController()
        let coordinator = makeHeightCoordinator(
            sleepController: sleepController,
            measuredHeight: { 120 }
        )
        let hostView = makeHostView(width: 320)
        let textView = makeTextView(width: 320)
        var callbackCount = 0

        coordinator.onHeightChange = { _, _ in
            callbackCount += 1
        }

        coordinator.scheduleHeightUpdate(
            hostView: hostView,
            contentRevision: 1,
            documentTextView: textView,
            configuration: makeConfiguration()
        )

        let didSchedule = await eventually(timeout: .milliseconds(100)) {
            sleepController.requestCount == 1
        }

        #expect(didSchedule)
        #expect(callbackCount == 0)

        sleepController.resumeNext()
        let firstWindowCompleted = await eventually(timeout: .milliseconds(100)) {
            sleepController.completedSleepCount == 1
        }
        #expect(firstWindowCompleted)

        let didNotify = await eventually(timeout: .milliseconds(100)) {
            callbackCount == 1
        }

        #expect(didNotify)
        #expect(sleepController.requestCount == 1)
    }

    @Test("Repeated schedule with same revision and width does not notify")
    func skipSameRevisionAndWidth() async {
        let sleepController = ControlledSleepController()
        let coordinator = makeHeightCoordinator(
            sleepController: sleepController,
            measuredHeight: { 120 }
        )
        let hostView = makeHostView(width: 320)
        let textView = makeTextView(width: 320)
        var callbackCount = 0

        coordinator.onHeightChange = { _, _ in
            callbackCount += 1
        }

        coordinator.scheduleHeightUpdate(
            hostView: hostView,
            contentRevision: 1,
            documentTextView: textView,
            configuration: makeConfiguration()
        )
        let firstWindowScheduled = await eventually(timeout: .milliseconds(100)) {
            sleepController.requestCount == 1
        }
        #expect(firstWindowScheduled)

        sleepController.resumeNext()
        let firstWindowCompleted = await eventually(timeout: .milliseconds(100)) {
            sleepController.completedSleepCount == 1
        }
        #expect(firstWindowCompleted)

        let firstNotificationArrived = await eventually(timeout: .milliseconds(100)) {
            callbackCount == 1
        }
        #expect(firstNotificationArrived)

        coordinator.scheduleHeightUpdate(
            hostView: hostView,
            contentRevision: 1,
            documentTextView: textView,
            configuration: makeConfiguration()
        )

        let secondWindowScheduled = await eventually(timeout: .milliseconds(100)) {
            sleepController.requestCount == 2
        }
        #expect(secondWindowScheduled)

        sleepController.resumeNext()
        let secondWindowFinished = await eventually(timeout: .milliseconds(100)) {
            sleepController.completedSleepCount == 2
        }
        #expect(secondWindowFinished)

        await Task.yield()
        #expect(callbackCount == 1)
    }

    @Test("Schedule uses latest revision captured within the coalescing window")
    func scheduleUsesLatestRevisionWithinWindow() async {
        let sleepController = ControlledSleepController()
        var measuredHeight: CGFloat = 120
        let coordinator = makeHeightCoordinator(
            sleepController: sleepController,
            measuredHeight: { measuredHeight }
        )
        let hostView = makeHostView(width: 320)
        let textView = makeTextView(width: 320)
        var callbackCount = 0

        coordinator.onHeightChange = { _, _ in
            callbackCount += 1
        }

        coordinator.scheduleHeightUpdate(
            hostView: hostView,
            contentRevision: 1,
            documentTextView: textView,
            configuration: makeConfiguration()
        )
        let firstWindowScheduled = await eventually(timeout: .milliseconds(100)) {
            sleepController.requestCount == 1
        }
        #expect(firstWindowScheduled)

        sleepController.resumeNext()
        let firstWindowCompleted = await eventually(timeout: .milliseconds(100)) {
            sleepController.completedSleepCount == 1
        }
        #expect(firstWindowCompleted)

        let firstNotificationArrived = await eventually(timeout: .milliseconds(100)) {
            callbackCount == 1
        }
        #expect(firstNotificationArrived)

        measuredHeight = 240
        coordinator.scheduleHeightUpdate(
            hostView: hostView,
            contentRevision: 1,
            documentTextView: textView,
            configuration: makeConfiguration()
        )
        coordinator.scheduleHeightUpdate(
            hostView: hostView,
            contentRevision: 2,
            documentTextView: textView,
            configuration: makeConfiguration()
        )

        let secondWindowScheduled = await eventually(timeout: .milliseconds(100)) {
            sleepController.requestCount == 2
        }
        #expect(secondWindowScheduled)

        sleepController.resumeNext()
        let secondWindowCompleted = await eventually(timeout: .milliseconds(100)) {
            sleepController.completedSleepCount == 2
        }
        #expect(secondWindowCompleted)

        let didNotifyAgain = await eventually(timeout: .milliseconds(100)) {
            callbackCount == 2
        }

        #expect(didNotifyAgain)
        #expect(sleepController.requestCount == 2)
    }
}

private extension HeightCoordinatorTests {
    func makeConfiguration() -> LayoutConfiguration {
        LayoutConfiguration(
            heightMeasurementCoalescingInterval: Self.coalescingWindow,
            heightNotificationMinimumDelta: 0.5
        )
    }

    func makeHeightCoordinator(
        sleepController: ControlledSleepController,
        measuredHeight: @escaping () -> CGFloat
    ) -> HeightCoordinator {
        HeightCoordinator(
            sleep: { duration in
                await sleepController.sleep(for: duration)
            },
            measureHeight: { _ in
                measuredHeight()
            }
        )
    }

    func makeHostView(width: CGFloat) -> UIView {
        UIView(frame: CGRect(x: 0, y: 0, width: width, height: 0))
    }

    func makeTextView(width: CGFloat) -> DocumentTextView {
        let textView = DocumentTextView()
        textView.frame = CGRect(x: 0, y: 0, width: width, height: 0)
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        return textView
    }
}
