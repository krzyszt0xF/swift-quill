import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Buffered Streaming Mode")
struct BufferedStreamingModeTests {
    @Test("Buffered mode avoids tiny first commit before safe threshold")
    func avoidsTinyFirstCommit() async throws {
        let view = makeBufferedModulesQuillView(minModuleLength: 180, maxBufferingDelay: 0.2)
        let container = try #require(containerView(for: view))

        view.append(String(repeating: "a", count: 150))
        await wait(for: .milliseconds(280))
        #expect(container.blockViews.isEmpty)

        view.append(String(repeating: "b", count: 220) + "\n\n")
        let renderedContent = await eventually(timeout: .seconds(1.2)) {
            container.blockViews.isEmpty == false
        }

        #expect(renderedContent)
        #expect(visibleTextCharacterCount(in: container) >= 180)
    }

    @Test("Finish does not force-complete queued reveal animation")
    func finishPreservesQueuedRevealAnimation() async throws {
        let view = makeBufferedModulesQuillView(minModuleLength: 120, maxBufferingDelay: 4.0)
        let container = try #require(containerView(for: view))

        view.append("Long paragraph: " + String(repeating: "x", count: 2200))
        view.finish()

        let revealInProgress = await eventually(timeout: .seconds(1.2)) {
            guard let textFlowView = container.blockViews.first(where: { $0 is TextFlowView }) as? TextFlowView else {
                return false
            }

            return textFlowView.totalCharacterCount > 0
                && textFlowView.lastRevealedIndex > 0
                && textFlowView.lastRevealedIndex < textFlowView.totalCharacterCount
        }

        #expect(revealInProgress)

        let textFlowView = try #require(container.blockViews.first { $0 is TextFlowView } as? TextFlowView)
        #expect(textFlowView.totalCharacterCount > 0)
        #expect(textFlowView.lastRevealedIndex < textFlowView.totalCharacterCount)
    }

    @Test("Buffered mode with slow chunks waits for larger module commit")
    func slowChunksPreferLargerCommit() async throws {
        let view = makeBufferedModulesQuillView(minModuleLength: 180, maxBufferingDelay: 4.0)
        let container = try #require(containerView(for: view))

        view.append(String(repeating: "x", count: 60))
        await wait(for: .milliseconds(420))
        #expect(container.blockViews.isEmpty)

        view.append(String(repeating: "y", count: 60))
        await wait(for: .milliseconds(420))
        #expect(container.blockViews.isEmpty)

        view.append(String(repeating: "z", count: 60))
        await wait(for: .milliseconds(420))
        #expect(container.blockViews.isEmpty)

        view.append(String(repeating: "k", count: 220) + "\n\n")
        let renderedContent = await eventually(timeout: .seconds(1.2)) {
            container.blockViews.isEmpty == false
        }

        #expect(renderedContent)
        #expect(visibleTextCharacterCount(in: container) >= 360)
    }
}

private extension BufferedStreamingModeTests {
    func visibleTextCharacterCount(in container: BlockContainerView) -> Int {
        container.blockViews.compactMap { ($0 as? TextFlowView)?.totalCharacterCount }.reduce(0, +)
    }
}
