@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Lifecycle")
struct QuillViewLifecycleTests {
    private static let timingTolerance: TimeInterval = 0.0001

    @Test("append accumulates currentMarkdown")
    func appendAccumulatesMarkdown() async {
        let view = makeStableBlocksQuillView()

        view.append("Hello ")
        #expect(view.currentMarkdown == "Hello ")

        view.append("world")
        #expect(view.currentMarkdown == "Hello world")
    }

    @Test("cancelStreaming is idempotent")
    func cancelStreamingRemainsIdempotent() {
        let view = makeStableBlocksQuillView()

        view.cancelStreaming()
        view.cancelStreaming()

        view.append("After cancel\n\n")
        view.cancelStreaming()
        view.cancelStreaming()

        #expect(view.currentMarkdown == "After cancel\n\n")
    }

    @Test("cancelStreaming then append auto-restarts stream")
    func appendAfterCancelRestartsStream() async {
        let view = makeStableBlocksQuillView()

        view.append("First chunk")
        view.cancelStreaming()

        view.append(" continued\n\n")
        #expect(view.currentMarkdown == "First chunk continued\n\n")

        let renderedContent = await eventually {
            (containerView(for: view)?.blockViews.count ?? 0) >= 1
        }
        #expect(renderedContent)
    }

    @Test("custom preset clamps speed multiplier")
    func customPresetClampsSpeedMultiplier() {
        let tooFastPreset = QuillStreamingPreset.custom(
            speedMultiplier: 3.0,
            bufferingDelay: 1.0
        )
        let tooSlowPreset = QuillStreamingPreset.custom(
            speedMultiplier: 0.1,
            bufferingDelay: 1.0
        )

        let fastConfiguration = RenderConfiguration(preset: tooFastPreset)
        let slowConfiguration = RenderConfiguration(preset: tooSlowPreset)
        let balancedConfiguration = RenderConfiguration(preset: .balanced)

        #expect(fastConfiguration.typewriter.lowQueue.baseDuration < balancedConfiguration.typewriter.lowQueue.baseDuration)
        #expect(slowConfiguration.typewriter.lowQueue.baseDuration > balancedConfiguration.typewriter.lowQueue.baseDuration)

        let expectedFastDuration = TypewriterConfiguration.balanced.lowQueue.baseDuration / 1.5
        let expectedSlowDuration = TypewriterConfiguration.balanced.lowQueue.baseDuration / 0.75
        #expect(abs(fastConfiguration.typewriter.lowQueue.baseDuration - expectedFastDuration) < Self.timingTolerance)
        #expect(abs(slowConfiguration.typewriter.lowQueue.baseDuration - expectedSlowDuration) < Self.timingTolerance)
    }

    @Test("finish then append auto-restarts stream")
    func appendAfterFinishRestartsStream() async {
        let view = makeStableBlocksQuillView()

        view.append("First paragraph\n\n")
        view.finish()

        view.append("Second paragraph\n\n")
        #expect(view.currentMarkdown == "First paragraph\n\nSecond paragraph\n\n")

        let renderedContent = await eventually {
            (containerView(for: view)?.blockViews.count ?? 0) >= 1
        }
        #expect(renderedContent)
    }

    @Test("finish is idempotent")
    func finishRemainsIdempotent() async {
        let view = makeStableBlocksQuillView()

        view.append("Content\n\n")
        view.finish()
        view.finish()
        view.finish()

        #expect(view.currentMarkdown == "Content\n\n")
    }

    @Test("preset change applies without crash")
    func presetSwitchPreservesUsableState() {
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.streamingPreset = .snappy
        view.streamingPreset = .longForm
        view.streamingPreset = .balanced

        #expect(view.streamingPreset == .balanced)
    }

    @Test("reset clears currentMarkdown and rendered content")
    func resetClearsContent() async {
        let view = makeStableBlocksQuillView()

        view.append("Some content\n\nMore content\n\n")

        view.reset()
        #expect(view.currentMarkdown == nil)
        #expect(containerView(for: view)?.blockViews.isEmpty == true)
    }

    @Test("static markdown assignment syncs currentMarkdown")
    func markdownAssignmentSyncsCurrentMarkdown() {
        let view = makeStableBlocksQuillView()

        view.markdown = "# Title"
        #expect(view.currentMarkdown == "# Title")

        view.markdown = "Updated"
        #expect(view.currentMarkdown == "Updated")

        view.markdown = nil
        #expect(view.currentMarkdown == nil)
    }

    @Test("static markdown assignment resets active reveal sequencing")
    func markdownAssignmentResetsActiveRevealSequencing() async throws {
        let view = makeStableBlocksQuillView()

        view.append("First paragraph with a [link](https://example.com) and enough extra text to keep reveal active for a moment.\n\n")

        let streamingRendered = await eventually {
            guard let container = containerView(for: view) else { return false }
            guard let flow = container.blockViews.first(where: { $0 is TextFlowView }) as? TextFlowView else { return false }
            return flow.totalCharacterCount > 0 && flow.originalAttributedString != nil
        }
        #expect(streamingRendered)

        view.markdown = "# Static Title\n\nStatic body."

        let staticRendered = await eventually {
            guard let container = containerView(for: view) else { return false }
            guard container.blockViews.count == 1 else { return false }
            guard let flow = container.blockViews.first as? TextFlowView else { return false }
            return flow.totalCharacterCount == 0 && flow.originalAttributedString == nil
        }
        #expect(staticRendered)

        let textFlowView = try #require(containerView(for: view)?.blockViews.first as? TextFlowView)
        #expect(textFlowView.totalCharacterCount == 0)
        #expect(textFlowView.originalAttributedString == nil)
    }
}
