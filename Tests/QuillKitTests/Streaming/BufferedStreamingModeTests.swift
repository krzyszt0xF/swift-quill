import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Buffered Streaming Mode", .tags(.integration, .streaming))
struct BufferedStreamingModeTests {
    @Test("Buffered mode avoids tiny first commit before safe threshold")
    func avoidsTinyFirstCommit() async throws {
        let timeController = TestTimeController()
        let view = makeBufferedModulesQuillView(
            minModuleLength: 180,
            maxBufferingDelay: 0.2,
            schedulerTimeController: timeController
        )

        view.append(String(repeating: "a", count: 150))
        await drainScheduledWork()
        #expect(documentHasContent(view) == false)
        #expect(timeController.recordedSleeps.isEmpty == false)

        view.append(String(repeating: "b", count: 220) + "\n\n")
        let renderedContent = await eventually(timeout: .milliseconds(200)) {
            documentHasContent(view)
        }

        #expect(renderedContent)
    }

    @Test("Buffered mode with slow chunks waits for larger module commit")
    func slowChunksPreferLargerCommit() async throws {
        let timeController = TestTimeController()
        let view = makeBufferedModulesQuillView(
            minModuleLength: 180,
            maxBufferingDelay: 4.0,
            schedulerTimeController: timeController
        )

        view.append(String(repeating: "x", count: 60))
        await drainScheduledWork()
        #expect(documentHasContent(view) == false)

        view.append(String(repeating: "y", count: 60))
        await drainScheduledWork()
        #expect(documentHasContent(view) == false)

        view.append(String(repeating: "z", count: 60))
        await drainScheduledWork()
        #expect(documentHasContent(view) == false)
        #expect(timeController.recordedSleeps.count >= 3)

        view.append(String(repeating: "k", count: 220) + "\n\n")
        let renderedContent = await eventually(timeout: .milliseconds(200)) {
            documentHasContent(view)
        }

        #expect(renderedContent)
    }
}

private extension BufferedStreamingModeTests {
    func drainScheduledWork() async {
        await Task.yield()
        await Task.yield()
        await Task.yield()
    }
}
