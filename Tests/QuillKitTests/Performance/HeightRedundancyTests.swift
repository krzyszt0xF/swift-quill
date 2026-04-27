@testable import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Height measurement redundancy", GloballySerialized())
struct HeightRedundancyTests {
    @Test("Stable revision and width do not remeasure")
    func stableRevisionAndWidthDoNotRemeasure() async {
        var measureCallCount = 0
        let sleepController = ControlledSleepController()
        let coordinator = HeightCoordinator(
            sleep: { duration in
                await sleepController.sleep(for: duration)
            },
            measureHeight: { _ in
                measureCallCount += 1
                return 500
            }
        )
        var heightNotificationCount = 0
        coordinator.onHeightChange = { _, _ in
            heightNotificationCount += 1
        }

        let textView = DocumentTextView(theme: .default)
        let hostView = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))

        coordinator.scheduleHeightUpdate(
            hostView: hostView,
            contentRevision: 1,
            documentTextView: textView,
            configuration: .default
        )

        let firstScheduled = await eventually(timeout: .milliseconds(100)) {
            sleepController.requestCount == 1
        }
        #expect(firstScheduled)
        sleepController.resumeNext()

        let firstCompleted = await eventually(timeout: .milliseconds(100)) {
            sleepController.completedSleepCount == 1
        }
        #expect(firstCompleted)
        #expect(measureCallCount == 1)
        #expect(heightNotificationCount == 1)

        let measureCountBefore = measureCallCount
        let notificationCountBefore = heightNotificationCount

        coordinator.scheduleHeightUpdate(
            hostView: hostView,
            contentRevision: 1,
            documentTextView: textView,
            configuration: .default
        )

        let secondScheduled = await eventually(timeout: .milliseconds(100)) {
            sleepController.requestCount == 2
        }
        #expect(secondScheduled)
        sleepController.resumeNext()

        let secondCompleted = await eventually(timeout: .milliseconds(100)) {
            sleepController.completedSleepCount == 2
        }
        #expect(secondCompleted)

        #expect(measureCallCount == measureCountBefore, "Measurer should not be called a second time for same revision and width")
        #expect(heightNotificationCount == notificationCountBefore, "No height notification should be emitted for unchanged content")
    }

    @Test("Streaming finish does not produce excessive height notifications")
    func streamingFinishDoesNotProduceExcessiveNotifications() async {
        var notificationCount = 0
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 375, height: 800))
        view.onHeightChange = { _, _ in
            notificationCount += 1
        }

        let chunks = makeSmallChunks(count: 20)
        for chunk in chunks {
            view.append(chunk)
        }

        let preFinishCount = notificationCount
        view.finish()

        await wait(for: .milliseconds(200))

        let postFinishNotifications = notificationCount - preFinishCount
        #expect(postFinishNotifications <= 2, "Post-finish height notifications should be bounded (0-2), got \(postFinishNotifications)")
    }
}

private extension HeightRedundancyTests {
    func makeSmallChunks(count: Int) -> [String] {
        (0..<count).map { index in
            "Chunk \(index) of streaming content. "
        }
    }
}
