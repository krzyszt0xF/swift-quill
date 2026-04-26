@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Lifecycle", .tags(.integration, .streaming))
struct QuillViewLifecycleTests {
    private static let timingTolerance: TimeInterval = 0.0001

    @Test("append accumulates accumulatedMarkdown")
    func appendAccumulatesMarkdown() async {
        let view = makeSmoothedTailQuillView()

        view.append("Hello ")
        #expect(view.accumulatedMarkdown == "Hello ")

        view.append("world")
        #expect(view.accumulatedMarkdown == "Hello world")
    }

    @Test("cancelStreaming is idempotent")
    func cancelStreamingRemainsIdempotent() {
        let view = makeSmoothedTailQuillView()

        view.cancelStreaming()
        view.cancelStreaming()

        view.append("After cancel\n\n")
        view.cancelStreaming()
        view.cancelStreaming()

        #expect(view.accumulatedMarkdown == "After cancel\n\n")
    }

    @Test("cancelStreaming then append auto-restarts stream")
    func appendAfterCancelRestartsStream() async {
        let view = makeSmoothedTailQuillView()

        view.append("First chunk")
        view.cancelStreaming()

        view.append(" continued\n\n")
        #expect(view.accumulatedMarkdown == "First chunk continued\n\n")

        let renderedContent = await eventually {
            view.hasDocumentContent
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

        #expect(fastConfiguration.tailReveal.lowQueue.baseDuration < balancedConfiguration.tailReveal.lowQueue.baseDuration)
        #expect(slowConfiguration.tailReveal.lowQueue.baseDuration > balancedConfiguration.tailReveal.lowQueue.baseDuration)

        let expectedFastDuration = TailRevealPolicy.balanced.lowQueue.baseDuration / 1.5
        let expectedSlowDuration = TailRevealPolicy.balanced.lowQueue.baseDuration / 0.75
        #expect(abs(fastConfiguration.tailReveal.lowQueue.baseDuration - expectedFastDuration) < Self.timingTolerance)
        #expect(abs(slowConfiguration.tailReveal.lowQueue.baseDuration - expectedSlowDuration) < Self.timingTolerance)
    }

    @Test("buffered custom preset clamps values and keeps module length")
    func bufferedCustomPresetClampsValues() {
        let preset = QuillStreamingPreset.bufferedCustom(
            speedMultiplier: 0.1,
            bufferingDelay: 0.01,
            minModuleLength: 0
        )

        let configuration = RenderConfiguration(preset: preset)
        let expectedDuration = TailRevealPolicy.balanced.lowQueue.baseDuration / 0.25

        #expect(abs(configuration.tailReveal.lowQueue.baseDuration - expectedDuration) < Self.timingTolerance)
        #expect(configuration.bufferedStream.maxBufferingDelay == 0.1)
        #expect(configuration.bufferedStream.minModuleLength == 1)
    }

    @Test("finish then append auto-restarts stream")
    func appendAfterFinishRestartsStream() async {
        let view = makeSmoothedTailQuillView()

        view.append("First paragraph\n\n")
        view.finish()

        view.append("Second paragraph\n\n")
        #expect(view.accumulatedMarkdown == "First paragraph\n\nSecond paragraph\n\n")

        let renderedContent = await eventually {
            view.hasDocumentContent
        }
        #expect(renderedContent)
    }

    @Test("finish is idempotent")
    func finishRemainsIdempotent() async {
        let view = makeSmoothedTailQuillView()

        view.append("Content\n\n")
        view.finish()
        view.finish()
        view.finish()

        #expect(view.accumulatedMarkdown == "Content\n\n")
    }

    @Test("preset change applies without crash")
    func presetSwitchPreservesUsableState() {
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.configuration.streaming.preset = .snappy
        view.configuration.streaming.preset = .longForm
        view.configuration.streaming.preset = .balanced

        #expect(view.configuration.streaming.preset == .balanced)
    }

    @Test("reset clears accumulatedMarkdown and rendered content")
    func resetClearsContent() async {
        let view = makeSmoothedTailQuillView()

        view.append("Some content\n\nMore content\n\n")

        view.reset()
        #expect(view.accumulatedMarkdown == nil)
        #expect(view.hasDocumentContent == false)
    }

    @Test("static markdown assignment syncs accumulatedMarkdown")
    func markdownAssignmentSyncsaccumulatedMarkdown() {
        let view = makeSmoothedTailQuillView()

        view.markdown = "# Title"
        #expect(view.accumulatedMarkdown == "# Title")

        view.markdown = "Updated"
        #expect(view.accumulatedMarkdown == "Updated")

        view.markdown = nil
        #expect(view.accumulatedMarkdown == nil)
    }

    @Test("static markdown assignment resets active streaming")
    func markdownAssignmentResetsActiveStreaming() async throws {
        let view = makeSmoothedTailQuillView()

        view.append("First paragraph with a [link](https://example.com) and enough extra text to keep streaming active for a moment.\n\n")

        let streamingRendered = await eventually {
            view.hasDocumentContent
        }
        #expect(streamingRendered)

        view.markdown = "# Static Title\n\nStatic body."

        let staticRendered = await eventually {
            view.hasDocumentContent
        }
        #expect(staticRendered)
    }
}
