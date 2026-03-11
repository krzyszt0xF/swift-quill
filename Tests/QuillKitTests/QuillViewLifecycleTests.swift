@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("QuillView Lifecycle")
struct QuillViewLifecycleTests {
    @Test("append accumulates currentMarkdown")
    func appendAccumulatesSnapshot() async {
        let view = makeQuillView()

        view.append("Hello ")
        #expect(view.currentMarkdown == "Hello ")

        view.append("world")
        #expect(view.currentMarkdown == "Hello world")
    }

    @Test("static markdown assignment syncs currentMarkdown")
    func staticMarkdownSyncsSnapshot() {
        let view = makeQuillView()

        view.markdown = "# Title"
        #expect(view.currentMarkdown == "# Title")

        view.markdown = "Updated"
        #expect(view.currentMarkdown == "Updated")

        view.markdown = nil
        #expect(view.currentMarkdown == nil)
    }

    @Test("reset clears currentMarkdown and rendered content")
    func resetClearsAll() async {
        let view = makeQuillView()

        view.append("Some content\n\nMore content\n\n")

        view.reset()
        #expect(view.currentMarkdown == nil)

        let stack = stackView(for: view)
        #expect(stack?.arrangedSubviews.isEmpty == true)
    }

    @Test("finish then append auto-restarts stream")
    func finishThenAppendAutoRestarts() async {
        let view = makeQuillView()

        view.append("First paragraph\n\n")
        view.finish()

        view.append("Second paragraph\n\n")
        #expect(view.currentMarkdown == "First paragraph\n\nSecond paragraph\n\n")

        let rendered = await eventually {
            (stackView(for: view)?.arrangedSubviews.count ?? 0) >= 1
        }
        #expect(rendered)
    }

    @Test("cancelStreaming then append auto-restarts stream")
    func cancelThenAppendAutoRestarts() async {
        let view = makeQuillView()

        view.append("First chunk")
        view.cancelStreaming()

        view.append(" continued\n\n")
        #expect(view.currentMarkdown == "First chunk continued\n\n")

        let rendered = await eventually {
            (stackView(for: view)?.arrangedSubviews.count ?? 0) >= 1
        }
        #expect(rendered)
    }

    @Test("finish is idempotent")
    func finishIsIdempotent() async {
        let view = makeQuillView()

        view.append("Content\n\n")
        view.finish()
        view.finish()
        view.finish()

        #expect(view.currentMarkdown == "Content\n\n")
    }

    @Test("cancelStreaming is idempotent")
    func cancelStreamingIsIdempotent() {
        let view = makeQuillView()

        view.cancelStreaming()
        view.cancelStreaming()

        view.append("After cancel\n\n")
        view.cancelStreaming()
        view.cancelStreaming()

        #expect(view.currentMarkdown == "After cancel\n\n")
    }

    @Test("preset change applies without crash")
    func presetChangeApplies() {
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0), streamingPreset: .balanced)
        view.streamingPreset = .snappy
        view.streamingPreset = .longForm
        view.streamingPreset = .balanced
    }

    @Test("custom preset clamps speed multiplier")
    func customPresetClampsSpeed() {
        let tooFast = QuillStreamingPreset.custom(speedMultiplier: 3.0, tailAggressiveness: .balanced, bufferingDelay: 1.0)
        let tooSlow = QuillStreamingPreset.custom(speedMultiplier: 0.1, tailAggressiveness: .balanced, bufferingDelay: 1.0)

        let fastConfig = QuillConfigurationMapper.resolve(tooFast)
        let slowConfig = QuillConfigurationMapper.resolve(tooSlow)
        let balancedConfig = QuillConfigurationMapper.resolve(.balanced)

        #expect(fastConfig.typewriter.lowQueue.baseDuration < balancedConfig.typewriter.lowQueue.baseDuration)
        #expect(slowConfig.typewriter.lowQueue.baseDuration > balancedConfig.typewriter.lowQueue.baseDuration)

        let expectedFastDuration = TypewriterConfiguration.balanced.lowQueue.baseDuration / 1.5
        let expectedSlowDuration = TypewriterConfiguration.balanced.lowQueue.baseDuration / 0.75
        #expect(abs(fastConfig.typewriter.lowQueue.baseDuration - expectedFastDuration) < 0.0001)
        #expect(abs(slowConfig.typewriter.lowQueue.baseDuration - expectedSlowDuration) < 0.0001)
    }
}

private extension QuillViewLifecycleTests {
    func makeQuillView() -> QuillView {
        let configuration = QuillRenderConfiguration(
            streamingMode: .hybridTail,
            performanceProfile: .balanced,
            typewriter: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.005),
            tail: .default
        )

        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0), internalConfiguration: configuration)
        view.layoutIfNeeded()
        return view
    }

    func stackView(for view: QuillView) -> UIStackView? {
        view.subviews.first { $0 is UIStackView } as? UIStackView
    }

    func eventually(
        timeoutMilliseconds: UInt64 = 800,
        pollMilliseconds: UInt64 = 10,
        _ condition: () -> Bool
    ) async -> Bool {
        let timeout = Date().addingTimeInterval(Double(timeoutMilliseconds) / 1000)

        while Date() < timeout {
            if condition() {
                return true
            }

            try? await Task.sleep(for: .milliseconds(pollMilliseconds))
        }

        return condition()
    }
}
