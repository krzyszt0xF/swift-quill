@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Streaming Equivalence", .tags(.integration, .parity, .streaming))
struct QuillViewStreamingEquivalenceTests {
    @Test("same markdown produces identical currentMarkdown across modes", arguments: StreamingMode.allCases)
    func modeEquivalence(mode: StreamingMode) async {
        let view = makeQuillView(mode: mode)
        let fullMarkdown = quillIntegrationMixedMarkdownFixture
        let markdownChunks = fullMarkdown.chunked(sizes: [4, 9, 6])

        for chunk in markdownChunks {
            view.append(chunk)
        }
        view.finish()

        let markdownMatched = await eventually { view.currentMarkdown == fullMarkdown }
        #expect(markdownMatched)
        #expect(view.currentMarkdown == fullMarkdown)
    }

    @Test(
        "same markdown produces identical currentMarkdown across presets",
        arguments: [
            QuillStreamingPreset.balanced,
            .bufferedCustom(
                speedMultiplier: 0.55,
                bufferingDelay: 1.2,
                minModuleLength: 120
            ),
            .snappy,
            .longForm,
        ]
    )
    func presetEquivalence(preset: QuillStreamingPreset) async {
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.streamingPreset = preset
        view.layoutIfNeeded()

        let fullMarkdown = quillIntegrationMixedMarkdownFixture
        let markdownChunks = fullMarkdown.chunked(sizes: [4, 9, 6])

        for chunk in markdownChunks {
            view.append(chunk)
        }
        view.finish()

        let markdownMatched = await eventually { view.currentMarkdown == fullMarkdown }
        #expect(markdownMatched)
        #expect(view.currentMarkdown == fullMarkdown)
    }
}
