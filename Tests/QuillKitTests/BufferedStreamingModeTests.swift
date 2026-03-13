import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("Buffered Streaming Mode")
struct BufferedStreamingModeTests {
    @Test("Buffered mode avoids tiny first commit before safe threshold")
    func avoidsTinyFirstCommit() async throws {
        let view = makeBufferedView(minModuleLength: 180, maxBufferingDelay: 0.2)
        let container = try #require(containerView(for: view))

        view.append(String(repeating: "a", count: 150))
        await wait(milliseconds: 280)
        #expect(container.blockViews.isEmpty)

        view.append(String(repeating: "b", count: 220) + "\n\n")
        let rendered = await eventually(timeout: .seconds(1.2)) {
            container.blockViews.isEmpty == false
        }

        #expect(rendered)
        #expect(visibleTextCharacterCount(in: container) >= 180)
    }

    @Test("Buffered mode with slow chunks waits for larger module commit")
    func slowChunksPreferLargerCommit() async throws {
        let view = makeBufferedView(minModuleLength: 180, maxBufferingDelay: 4.0)
        let container = try #require(containerView(for: view))

        view.append(String(repeating: "x", count: 60))
        await wait(milliseconds: 420)
        #expect(container.blockViews.isEmpty)

        view.append(String(repeating: "y", count: 60))
        await wait(milliseconds: 420)
        #expect(container.blockViews.isEmpty)

        view.append(String(repeating: "z", count: 60))
        await wait(milliseconds: 420)
        #expect(container.blockViews.isEmpty)

        view.append(String(repeating: "k", count: 220) + "\n\n")
        let rendered = await eventually(timeout: .seconds(1.2)) {
            container.blockViews.isEmpty == false
        }

        #expect(rendered)
        #expect(visibleTextCharacterCount(in: container) >= 360)
    }

    @Test("Finish does not force-complete queued reveal animation")
    func finishDoesNotForceCompleteQueuedReveal() async throws {
        let view = makeBufferedView(minModuleLength: 120, maxBufferingDelay: 4.0)
        let container = try #require(containerView(for: view))

        view.append("Long paragraph: " + String(repeating: "x", count: 2200))
        view.finish()

        let revealInProgress = await eventually(timeout: .seconds(1.2)) {
            guard let textFlow = container.blockViews.first(where: { $0 is TextFlowView }) as? TextFlowView else {
                return false
            }

            return textFlow.totalCharacterCount > 0
                && textFlow.lastRevealedIndex > 0
                && textFlow.lastRevealedIndex < textFlow.totalCharacterCount
        }

        #expect(revealInProgress)

        let textFlow = try #require(container.blockViews.first { $0 is TextFlowView } as? TextFlowView)
        #expect(textFlow.totalCharacterCount > 0)
        #expect(textFlow.lastRevealedIndex < textFlow.totalCharacterCount)
    }
}

private extension BufferedStreamingModeTests {
    func makeBufferedView(minModuleLength: Int, maxBufferingDelay: TimeInterval) -> QuillView {
        let configuration = QuillRenderConfiguration(
            streamingMode: .bufferedModules,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.005),
            tail: .default,
            bufferedStream: .init(
                minModuleLength: minModuleLength,
                maxBufferingDelay: maxBufferingDelay
            )
        )

        return QuillView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 0),
            internalConfiguration: configuration
        )
    }

    func containerView(for view: QuillView) -> BlockContainerView? {
        view.subviews.first { $0 is BlockContainerView } as? BlockContainerView
    }

    func visibleTextCharacterCount(in container: BlockContainerView) -> Int {
        container.blockViews.compactMap { ($0 as? TextFlowView)?.totalCharacterCount }.reduce(0, +)
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

    func wait(milliseconds: UInt64) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}
