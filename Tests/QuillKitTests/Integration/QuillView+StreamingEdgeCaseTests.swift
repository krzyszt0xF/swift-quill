@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Streaming Edge Cases", .serialized, GloballySerialized(), .tags(.integration, .streaming))
struct QuillViewStreamingEdgeCaseTests {
    @Test("chunk boundary inside markdown syntax produces correct result")
    func chunkBoundariesInsideSyntaxPreserveOutput() async {
        let codeFenceView = makeSmoothedTailQuillView()
        let codeFenceMarkdown = "```swift\nlet x = 1\n```\n\n"
        let codeFenceChunks = codeFenceMarkdown.chunked(sizes: [2, 3, 4])

        for chunk in codeFenceChunks {
            codeFenceView.append(chunk)
        }
        codeFenceView.finish()

        let codeFenceMatched = await eventually { codeFenceView.accumulatedMarkdown == codeFenceMarkdown }
        #expect(codeFenceMatched)
        #expect(codeFenceView.accumulatedMarkdown == codeFenceMarkdown)

        let boldTextView = makeSmoothedTailQuillView()
        let boldMarkdown = "**bold text**\n\n"
        let boldChunks = boldMarkdown.chunked(sizes: [1])

        for chunk in boldChunks {
            boldTextView.append(chunk)
        }
        boldTextView.finish()

        let boldMarkdownMatched = await eventually { boldTextView.accumulatedMarkdown == boldMarkdown }
        #expect(boldMarkdownMatched)
        #expect(boldTextView.accumulatedMarkdown == boldMarkdown)
    }

    @Test("empty chunks do not corrupt accumulatedMarkdown")
    func emptyChunksPreserveMarkdownOutput() async {
        let view = makeSmoothedTailQuillView()
        let appendedParts = ["# Title", "", "\n\n", "", "Body text.\n\n", ""]

        for part in appendedParts {
            view.append(part)
        }
        view.finish()

        let expectedMarkdown = "# Title\n\nBody text.\n\n"
        let markdownMatched = await eventually { view.accumulatedMarkdown == expectedMarkdown }
        #expect(markdownMatched)
        #expect(view.accumulatedMarkdown == expectedMarkdown)
    }

    @Test("large single chunk produces correct accumulatedMarkdown")
    func largeSingleChunkPreservesMarkdown() async {
        let view = makeSmoothedTailQuillView()
        let largeMarkdown = makeQuillIntegrationLargeMarkdown()

        view.append(largeMarkdown)
        view.finish()

        let markdownMatched = await eventually { view.accumulatedMarkdown == largeMarkdown }
        #expect(markdownMatched)
        #expect(view.accumulatedMarkdown == largeMarkdown)
    }

    @Test("rapid successive appends produce correct cumulative result")
    func rapidSuccessiveAppendsAccumulateMarkdown() async {
        let view = makeSmoothedTailQuillView()
        let fullMarkdown = quillIntegrationMixedMarkdownFixture
        let markdownChunks = fullMarkdown.chunked(sizes: [2, 3])

        for chunk in markdownChunks {
            view.append(chunk)
        }
        view.finish()

        let markdownMatched = await eventually(timeout: .milliseconds(800)) {
            view.accumulatedMarkdown == fullMarkdown
        }
        #expect(markdownMatched)
        #expect(view.accumulatedMarkdown == fullMarkdown)
    }

    @Test("Closed code block renders code block attachment")
    func closedCodeBlockRendersCodeBlockAttachment() async {
        let view = makeSmoothedTailQuillView()
        let markdown = "```swift\nlet value = 1\n```\n"

        view.append(markdown)
        view.finish()

        let rendered = await eventually(timeout: .milliseconds(1200)) {
            view.hasCodeBlockAttachment
        }

        #expect(rendered)
        #expect(view.accumulatedMarkdown == markdown)
    }

    @Test("Nested list code fence renders code block attachment")
    func nestedListCodeFenceRendersAttachment() async {
        let view = makeSmoothedTailQuillView()
        let markdown = """
        1. Headings:
           - `#`
             ```markdown
             # Heading 1
             ```
           - `##`
             ```python
             print("Hello")
             ```

        """

        for chunk in markdown.chunked(sizes: [4, 7, 5, 3]) {
            view.append(chunk)
        }
        view.finish()

        let renderedCodeBlock = await eventually(timeout: .milliseconds(1200)) {
            view.hasCodeBlockAttachment
        }

        #expect(renderedCodeBlock)
    }
}
