@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Streaming Edge Cases")
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

        let codeFenceMatched = await eventually { codeFenceView.currentMarkdown == codeFenceMarkdown }
        #expect(codeFenceMatched)
        #expect(codeFenceView.currentMarkdown == codeFenceMarkdown)

        let boldTextView = makeSmoothedTailQuillView()
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
        let view = makeSmoothedTailQuillView()
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
        let view = makeSmoothedTailQuillView()
        let largeMarkdown = makeQuillIntegrationLargeMarkdown()

        view.append(largeMarkdown)
        view.finish()

        let markdownMatched = await eventually { view.currentMarkdown == largeMarkdown }
        #expect(markdownMatched)
        #expect(view.currentMarkdown == largeMarkdown)
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
            view.currentMarkdown == fullMarkdown
        }
        #expect(markdownMatched)
        #expect(view.currentMarkdown == fullMarkdown)
    }

    @Test("Closed code block renders selectable text view")
    func closedCodeBlockRendersSelectableTextView() async {
        let view = makeSmoothedTailQuillView()

        view.append("```swift\nlet value = 1\n```\n")
        view.finish()

        let rendered = await eventually(timeout: .milliseconds(1200)) {
            guard let codeBlockView = documentCodeBlockView(for: view),
                  let codeTextView = findSubview(
                    of: UITextView.self,
                    in: codeBlockView,
                    matching: { $0.isSelectable && $0.isEditable == false }
                  )
            else { return false }

            return codeTextView.attributedText.string.contains("let value = 1")
        }

        #expect(rendered)
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
            documentHasCodeBlockAttachment(view)
        }

        #expect(renderedCodeBlock)
    }
}
