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
        let stack = try #require(stackView(for: view))

        view.append(String(repeating: "a", count: 150))
        await wait(milliseconds: 280)
        #expect(stack.arrangedSubviews.isEmpty)

        view.append(String(repeating: "b", count: 220) + "\n\n")
        await wait(milliseconds: 320)

        #expect(stack.arrangedSubviews.isEmpty == false)
        #expect(visibleTextCharacterCount(in: stack) >= 180)
    }

    @Test("Buffered mode with slow chunks waits for larger module commit")
    func slowChunksPreferLargerCommit() async throws {
        let view = makeBufferedView(minModuleLength: 180, maxBufferingDelay: 4.0)
        let stack = try #require(stackView(for: view))

        view.append(String(repeating: "x", count: 60))
        await wait(milliseconds: 420)
        #expect(stack.arrangedSubviews.isEmpty)

        view.append(String(repeating: "y", count: 60))
        await wait(milliseconds: 420)
        #expect(stack.arrangedSubviews.isEmpty)

        view.append(String(repeating: "z", count: 60))
        await wait(milliseconds: 420)
        #expect(stack.arrangedSubviews.isEmpty)

        view.append(String(repeating: "k", count: 220) + "\n\n")
        await wait(milliseconds: 320)

        #expect(stack.arrangedSubviews.isEmpty == false)
        #expect(visibleTextCharacterCount(in: stack) >= 360)
    }

    @Test("Finish does not force-complete queued reveal animation")
    func finishDoesNotForceCompleteQueuedReveal() async throws {
        let view = makeBufferedView(minModuleLength: 120, maxBufferingDelay: 4.0)
        let stack = try #require(stackView(for: view))

        view.append("Long paragraph: " + String(repeating: "x", count: 2200))
        view.finish()

        await wait(milliseconds: 60)

        let textFlow = try #require(stack.arrangedSubviews.first { $0 is TextFlowView } as? TextFlowView)
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

    func stackView(for view: QuillView) -> UIStackView? {
        view.subviews.first { $0 is UIStackView } as? UIStackView
    }

    func visibleTextCharacterCount(in stack: UIStackView) -> Int {
        stack.arrangedSubviews.compactMap { ($0 as? TextFlowView)?.totalCharacterCount }.reduce(0, +)
    }

    func wait(milliseconds: UInt64) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}
