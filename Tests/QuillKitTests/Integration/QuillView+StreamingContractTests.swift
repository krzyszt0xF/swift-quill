@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("QuillView Streaming Contract", .tags(.integration, .streaming))
struct QuillViewStreamingContractTests {
    @Test("append + finish produces identical currentMarkdown to chunk concatenation")
    func streamedAndStaticMarkdownMatch() async {
        let streamedView = makeSmoothedTailQuillView()
        let staticView = makeSmoothedTailQuillView()
        let fullMarkdown = quillIntegrationMixedMarkdownFixture
        let markdownChunks = fullMarkdown.chunked(sizes: [3, 7, 5, 9, 4])

        for chunk in markdownChunks {
            streamedView.append(chunk)
        }
        streamedView.finish()
        staticView.markdown = fullMarkdown

        let markdownMatched = await eventually { streamedView.currentMarkdown == fullMarkdown }
        let streamedContentRendered = await eventually {
            streamedView.hasDocumentContent
        }
        let staticContentRendered = await eventually {
            staticView.hasDocumentContent
        }
        let codeBlockRendered = await eventually(timeout: .milliseconds(1200)) {
            streamedView.hasCodeBlockAttachment
        }

        #expect(markdownMatched)
        #expect(streamedContentRendered)
        #expect(staticContentRendered)
        #expect(codeBlockRendered)
        #expect(streamedView.currentMarkdown == fullMarkdown)
    }

    @Test("finish flushes buffered incomplete content")
    func finishFlushesBufferedIncompleteContent() async {
        let view = makeSmoothedTailQuillView()
        let incompleteMarkdown = "# Title\n\n```swift\nlet x = 1"
        let markdownChunks = incompleteMarkdown.chunked(sizes: [5, 8, 6])

        for chunk in markdownChunks {
            view.append(chunk)
        }

        let renderedContentBeforeFinish = await eventually {
            view.hasDocumentContent
        }
        let codeBlockBeforeFinish = view.hasCodeBlockAttachment

        view.finish()

        let markdownMatched = await eventually { view.currentMarkdown == incompleteMarkdown }

        #expect(renderedContentBeforeFinish)
        #expect(codeBlockBeforeFinish == false)
        #expect(markdownMatched)
        #expect(view.currentMarkdown == incompleteMarkdown)
    }

    @Test("cancelStreaming preserves already-appended currentMarkdown")
    func cancelPreservesRenderedContent() {
        let view = makeSmoothedTailQuillView()

        view.append("First chunk. ")
        view.append("Second chunk.\n\n")
        view.cancelStreaming()

        #expect(view.currentMarkdown == "First chunk. Second chunk.\n\n")
    }

    @Test("cancelStreaming does not flush buffered incomplete content or finish the stream")
    func cancelDoesNotFlushBufferedIncompleteContentOrFinish() async {
        let view = makeSmoothedTailQuillView()
        let incompleteMarkdown = "# Title\n\n```swift\nlet x = 1"
        let markdownChunks = incompleteMarkdown.chunked(sizes: [5, 8, 6])
        var finished = false

        view.onStreamFinished = {
            finished = true
        }

        for chunk in markdownChunks {
            view.append(chunk)
        }

        let renderedContentBeforeCancel = await eventually {
            view.hasDocumentContent
        }
        #expect(renderedContentBeforeCancel)
        #expect(view.hasCodeBlockAttachment == false)

        view.cancelStreaming()
        await wait(for: .milliseconds(200))

        #expect(view.currentMarkdown == incompleteMarkdown)
        #expect(view.hasCodeBlockAttachment == false)
        #expect(finished == false)
    }

    @Test("append after finish auto-restarts a new stream session")
    func appendAfterFinishRestartsStream() async {
        let view = makeSmoothedTailQuillView()

        view.append("First paragraph\n\n")
        view.finish()

        view.append("Second paragraph\n\n")

        #expect(view.currentMarkdown == "First paragraph\n\nSecond paragraph\n\n")

        let renderedContent = await eventually {
            view.hasDocumentContent
        }
        #expect(renderedContent)
    }

    @Test("append after cancel auto-restarts a new stream session")
    func appendAfterCancelRestartsStream() async {
        let view = makeSmoothedTailQuillView()

        view.append("Before cancel\n\n")
        view.cancelStreaming()

        view.append("After cancel\n\n")

        #expect(view.currentMarkdown == "Before cancel\n\nAfter cancel\n\n")

        let renderedContent = await eventually {
            view.hasDocumentContent
        }
        #expect(renderedContent)
    }

    @Test("reapplying syntaxHighlighter after finish preserves highlighted code")
    func reapplyingSyntaxHighlighterAfterFinishPreservesHighlighting() async {
        let view = makeSmoothedTailQuillView()
        let highlighter = StaticColorHighlighter()
        let markdown = """
        ```swift
        let x = 1
        ```
        """

        view.syntaxHighlighter = highlighter
        view.append(markdown)
        view.finish()

        let highlightedInitially = await eventually(timeout: .milliseconds(1200)) {
            highlightedKeywordColor(in: view) == UIColor.systemRed
        }
        #expect(highlightedInitially)
        #expect(highlighter.callCount == 1)

        view.syntaxHighlighter = highlighter
        let currentConfiguration = view.configuration
        view.configuration = currentConfiguration

        let highlightPreserved = await eventually(timeout: .milliseconds(1200)) {
            highlightedKeywordColor(in: view) == UIColor.systemRed
        }
        #expect(highlightPreserved)
        #expect(highlighter.callCount == 1)
    }

    @Test("reset clears currentMarkdown to nil")
    func resetClearsMarkdown() {
        let view = makeSmoothedTailQuillView()

        view.append("Some content\n\nMore content\n\n")
        #expect(view.currentMarkdown != nil)

        view.reset()

        #expect(view.currentMarkdown == nil)
        #expect(view.hasDocumentContent == false)
    }
}

private extension QuillViewStreamingContractTests {
    func highlightedKeywordColor(in view: QuillView) -> UIColor? {
        let codeBlockView = view.firstCodeBlockView()
        let textView: UITextView? = codeBlockView?.firstSubview()
        return textView?.attributedText?.attribute(
            .foregroundColor,
            at: 1,
            effectiveRange: nil
        ) as? UIColor
    }

    final class StaticColorHighlighter: SyntaxHighlighting, @unchecked Sendable {
        private let lock = NSLock()
        private var callCountValue = 0

        var callCount: Int {
            lock.withLock {
                callCountValue
            }
        }

        func highlight(code: String, language: String) -> NSAttributedString? {
            lock.withLock {
                callCountValue += 1
            }

            let highlighted = NSMutableAttributedString(string: code)
            highlighted.addAttribute(
                .foregroundColor,
                value: UIColor.systemRed,
                range: NSRange(location: 0, length: min(3, highlighted.length))
            )
            return highlighted
        }
    }
}
