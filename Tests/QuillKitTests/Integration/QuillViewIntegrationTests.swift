@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Integration")
struct QuillViewIntegrationTests {
    private static let largeMarkdownSectionCount = 10

    // MARK: - Contract Tests

    @Test("append + finish produces identical currentMarkdown to chunk concatenation")
    func streamedAndStaticMarkdownMatch() async {
        let streamedView = makeStableBlocksQuillView()
        let staticView = makeStableBlocksQuillView()
        let fullMarkdown = mixedMarkdownFixture
        let markdownChunks = fullMarkdown.chunked(sizes: [3, 7, 5, 9, 4])

        for chunk in markdownChunks {
            streamedView.append(chunk)
        }
        streamedView.finish()
        staticView.markdown = fullMarkdown

        let markdownMatched = await eventually { streamedView.currentMarkdown == fullMarkdown }
        let streamedContentRendered = await eventually {
            containerView(for: streamedView)?.blockViews.isEmpty == false
        }
        let staticContentRendered = await eventually {
            containerView(for: staticView)?.blockViews.isEmpty == false
        }
        let structuralNodesMatched = await eventually(timeout: .milliseconds(1200)) {
            structuralSignatures(for: streamedView) == structuralSignatures(for: staticView)
        }
        let streamedSignatures = viewSignatures(for: streamedView)
        let staticSignatures = viewSignatures(for: staticView)
        let streamedStructuralSignatures = streamedSignatures.filter { $0 != "flow" }
        let staticStructuralSignatures = staticSignatures.filter { $0 != "flow" }

        #expect(markdownMatched)
        #expect(streamedContentRendered)
        #expect(staticContentRendered)
        #expect(structuralNodesMatched)
        #expect(streamedView.currentMarkdown == fullMarkdown)
        #expect(streamedStructuralSignatures == staticStructuralSignatures)
        #expect(streamedSignatures.filter { $0 == "code" }.count == 1)
        #expect(streamedSignatures.filter { $0 == "table" }.count == 1)
        #expect(streamedSignatures.contains("code"))
        #expect(streamedSignatures.contains("table"))
    }

    @Test("finish flushes buffered tail content")
    func finishFlushesBufferedTail() async {
        let view = makeStableBlocksQuillView()
        let incompleteMarkdown = "# Title\n\n```swift\nlet x = 1"
        let markdownChunks = incompleteMarkdown.chunked(sizes: [5, 8, 6])

        for chunk in markdownChunks {
            view.append(chunk)
        }

        let renderedContentBeforeFinish = await eventually {
            containerView(for: view)?.blockViews.isEmpty == false
        }
        let signaturesBeforeFinish = viewSignatures(for: view)

        view.finish()

        let markdownMatched = await eventually { view.currentMarkdown == incompleteMarkdown }
        let renderedCodeBlockAfterFinish = await eventually {
            viewSignatures(for: view).contains("code")
        }
        let signaturesAfterFinish = viewSignatures(for: view)

        #expect(renderedContentBeforeFinish)
        #expect(signaturesBeforeFinish.contains("code") == false)
        #expect(markdownMatched)
        #expect(view.currentMarkdown == incompleteMarkdown)
        #expect(renderedCodeBlockAfterFinish)
        #expect(signaturesAfterFinish.contains("code"))
    }

    @Test("cancelStreaming preserves already-appended currentMarkdown")
    func cancelPreservesRenderedContent() {
        let view = makeStableBlocksQuillView()

        view.append("First chunk. ")
        view.append("Second chunk.\n\n")
        view.cancelStreaming()

        #expect(view.currentMarkdown == "First chunk. Second chunk.\n\n")
    }

    @Test("append after finish auto-restarts a new stream session")
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

    @Test("append after cancel auto-restarts a new stream session")
    func appendAfterCancelRestartsStream() async {
        let view = makeStableBlocksQuillView()

        view.append("Before cancel\n\n")
        view.cancelStreaming()

        view.append("After cancel\n\n")

        #expect(view.currentMarkdown == "Before cancel\n\nAfter cancel\n\n")

        let renderedContent = await eventually {
            (containerView(for: view)?.blockViews.count ?? 0) >= 1
        }
        #expect(renderedContent)
    }

    @Test("reset clears currentMarkdown to nil")
    func resetClearsMarkdown() {
        let view = makeStableBlocksQuillView()

        view.append("Some content\n\nMore content\n\n")
        #expect(view.currentMarkdown != nil)

        view.reset()

        #expect(view.currentMarkdown == nil)
        #expect(containerView(for: view)?.blockViews.isEmpty == true)
    }

    // MARK: - Equivalence Tests

    @Test("same markdown produces identical currentMarkdown across modes", arguments: StreamingMode.allCases)
    func modeEquivalence(mode: StreamingMode) async {
        let view = makeQuillView(mode: mode)
        let fullMarkdown = mixedMarkdownFixture
        let markdownChunks = fullMarkdown.chunked(sizes: [4, 9, 6])

        for chunk in markdownChunks {
            view.append(chunk)
        }
        view.finish()

        let markdownMatched = await eventually { view.currentMarkdown == fullMarkdown }
        #expect(markdownMatched)
        #expect(view.currentMarkdown == fullMarkdown)
    }

    @Test("same markdown produces identical currentMarkdown across presets", arguments: [QuillStreamingPreset.balanced, .snappy, .longForm])
    func presetEquivalence(preset: QuillStreamingPreset) async {
        let view = QuillView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.streamingPreset = preset
        view.layoutIfNeeded()

        let fullMarkdown = mixedMarkdownFixture
        let markdownChunks = fullMarkdown.chunked(sizes: [4, 9, 6])

        for chunk in markdownChunks {
            view.append(chunk)
        }
        view.finish()

        let markdownMatched = await eventually { view.currentMarkdown == fullMarkdown }
        #expect(markdownMatched)
        #expect(view.currentMarkdown == fullMarkdown)
    }

    // MARK: - Edge Cases

    @Test("chunk boundary inside markdown syntax produces correct result")
    func chunkBoundariesInsideSyntaxPreserveOutput() async {
        let codeFenceView = makeStableBlocksQuillView()
        let codeFenceMarkdown = "```swift\nlet x = 1\n```\n\n"
        let codeFenceChunks = codeFenceMarkdown.chunked(sizes: [2, 3, 4])

        for chunk in codeFenceChunks {
            codeFenceView.append(chunk)
        }
        codeFenceView.finish()

        let codeFenceMatched = await eventually { codeFenceView.currentMarkdown == codeFenceMarkdown }
        #expect(codeFenceMatched)
        #expect(codeFenceView.currentMarkdown == codeFenceMarkdown)

        let boldTextView = makeStableBlocksQuillView()
        let boldMarkdown = "**bold text**\n\n"
        let boldChunks = boldMarkdown.chunked(sizes: [1])

        for chunk in boldChunks {
            boldTextView.append(chunk)
        }
        boldTextView.finish()

        let boldMarkdownMatched = await eventually { boldTextView.currentMarkdown == boldMarkdown }
        #expect(boldMarkdownMatched)
        #expect(boldTextView.currentMarkdown == boldMarkdown)
    }

    @Test("empty chunks do not corrupt currentMarkdown")
    func emptyChunksPreserveMarkdownOutput() async {
        let view = makeStableBlocksQuillView()
        let appendedParts = ["# Title", "", "\n\n", "", "Body text.\n\n", ""]

        for part in appendedParts {
            view.append(part)
        }
        view.finish()

        let expectedMarkdown = "# Title\n\nBody text.\n\n"
        let markdownMatched = await eventually { view.currentMarkdown == expectedMarkdown }
        #expect(markdownMatched)
        #expect(view.currentMarkdown == expectedMarkdown)
    }

    @Test("large single chunk produces correct currentMarkdown")
    func largeSingleChunkPreservesMarkdown() async {
        let view = makeStableBlocksQuillView()
        let largeMarkdown = makeLargeMarkdown()

        view.append(largeMarkdown)
        view.finish()

        let markdownMatched = await eventually { view.currentMarkdown == largeMarkdown }
        #expect(markdownMatched)
        #expect(view.currentMarkdown == largeMarkdown)
    }

    @Test("rapid successive appends produce correct cumulative result")
    func rapidSuccessiveAppendsAccumulateMarkdown() async {
        let view = makeStableBlocksQuillView()
        let fullMarkdown = mixedMarkdownFixture
        let markdownChunks = fullMarkdown.chunked(sizes: [2, 3])

        for chunk in markdownChunks {
            view.append(chunk)
        }
        view.finish()

        let markdownMatched = await eventually(timeout: .milliseconds(800)) {
            view.currentMarkdown == fullMarkdown
        }
        #expect(markdownMatched)
        #expect(view.currentMarkdown == fullMarkdown)
    }
}

private extension QuillViewIntegrationTests {
    var mixedMarkdownFixture: String {
        """
        # Integration Test Heading

        A paragraph with **bold** and *italic* formatting.

        - First item
        - Second item
        - Third item

        ```swift
        let code = "example"
        print(code)
        ```

        > A blockquote with some wisdom.

        ---

        | Column A | Column B |
        |----------|----------|
        | Cell 1   | Cell 2   |
        | Cell 3   | Cell 4   |

        Final paragraph to close out the fixture.

        """
    }

    func makeLargeMarkdown() -> String {
        var markdown = "# Large Document\n\n"
        for sectionIndex in 1...Self.largeMarkdownSectionCount {
            markdown += "## Section \(sectionIndex)\n\n"
            markdown += "This is paragraph content for section \(sectionIndex). It contains enough text to contribute meaningfully to the total character count of the document.\n\n"
            markdown += "- Item \(sectionIndex)a with some detail\n- Item \(sectionIndex)b with more detail\n- Item \(sectionIndex)c with even more detail\n\n"
        }
        markdown += "```\nfinal code block content\nwith multiple lines\n```\n\n"
        return markdown
    }
}
