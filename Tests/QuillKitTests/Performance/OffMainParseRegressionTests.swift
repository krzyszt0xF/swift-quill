import Foundation
import Testing
@testable import QuillKit
@testable import QuillCore
import QuillSharedTestSupport
import UIKit

@MainActor
@Suite("Off-main parse regression", .serialized, GloballySerialized())
struct OffMainParseRegressionTests {
    @Test("Static markdown produces rendered content")
    func staticMarkdownProducesRenderedContent() async {
        let view = makeSmoothedTailQuillView()

        view.markdown = "# Hello\n\nWorld"

        let rendered = await eventually {
            view.hasDocumentContent
        }

        #expect(view.accumulatedMarkdown == "# Hello\n\nWorld")
        #expect(rendered)
    }

    @Test("Rapid markdown reassignment uses latest value")
    func rapidMarkdownReassignmentUsesLatestValue() async {
        let latch = OffMainParseLatch()
        let view = makeQuillView(parser: makeLatchParser(latch: latch))
        let first = makeLargeStaticMarkdown(marker: "FirstDoc")
        let second = makeLargeStaticMarkdown(marker: "SecondDoc")

        view.markdown = first
        view.markdown = second

        latch.releaseAll()

        let rendered = await eventually(timeout: .milliseconds(1500)) {
            view.hasDocumentContent
        }

        #expect(view.accumulatedMarkdown == second)
        #expect(rendered)

        let documentText = renderedDocumentText(from: view)
        #expect(documentText?.contains("FirstDoc") != true)
    }

    // Still disabled: the >16 KB async fixture pushes the appended chunk past what smoothedTail
    // reveals within the timeout; needs a reworked assertion.
    @Test(
        "Append cancels in-flight static parse",
        .disabled("appended chunk lands past the smoothedTail reveal window for a >16 KB async fixture")
    )
    func appendCancelsInflightStaticParse() async {
        let latch = OffMainParseLatch()
        let view = makeQuillView(parser: makeLatchParser(latch: latch))
        let longFixture = makeLargeStaticMarkdown(marker: "AppendDoc")

        view.markdown = longFixture
        view.append("streaming chunk\n\n")

        latch.releaseAll()

        let expectedMarkdown = longFixture + "streaming chunk\n\n"
        #expect(view.accumulatedMarkdown == expectedMarkdown)

        let rendered = await eventually(timeout: .milliseconds(1500)) {
            let text = renderedDocumentText(from: view)
            return text?.contains("streaming chunk") == true
        }
        #expect(rendered)

        await wait(for: .milliseconds(300))
        let textAfterDrain = renderedDocumentText(from: view)
        #expect(textAfterDrain?.contains("streaming chunk") == true)
    }

    @Test("Reset cancels in-flight static parse")
    func resetCancelsInflightStaticParse() async {
        let latch = OffMainParseLatch()
        let view = makeQuillView(parser: makeLatchParser(latch: latch))
        let longFixture = makeLargeStaticMarkdown(marker: "ResetDoc")

        view.markdown = longFixture
        view.reset()

        #expect(view.accumulatedMarkdown == nil)

        latch.releaseAll()

        await wait(for: .milliseconds(300))
        #expect(view.accumulatedMarkdown == nil)
        #expect(view.hasDocumentContent == false)
    }

    @Test("Empty markdown clears content synchronously")
    func emptyMarkdownClearsContentSynchronously() async {
        let view = makeSmoothedTailQuillView()

        view.markdown = "# Test"

        let rendered = await eventually {
            view.hasDocumentContent
        }
        #expect(rendered)

        view.markdown = nil

        #expect(view.accumulatedMarkdown == nil)
        #expect(view.hasDocumentContent == false)
    }

    @Test("Configuration change cancels pending static parse")
    func configurationChangeCancelsPendingStaticParse() async {
        let latch = OffMainParseLatch()
        let view = makeQuillView(parser: makeLatchParser(latch: latch))
        let original = makeLargeStaticMarkdown(marker: "OriginalDoc")

        view.markdown = original

        var updated = view.configuration
        updated.streaming.preset = .snappy
        view.configuration = updated

        latch.releaseAll()

        let rendered = await eventually(timeout: .milliseconds(1500)) {
            view.hasDocumentContent
        }

        #expect(rendered)
        #expect(view.accumulatedMarkdown == original)
    }
}

private final class OffMainParseLatch: @unchecked Sendable {
    private let condition = NSCondition()
    private var released = false

    func releaseAll() {
        condition.lock()
        defer { condition.unlock() }
        released = true
        condition.broadcast()
    }

    func wait() {
        condition.lock()
        defer { condition.unlock() }
        while released == false {
            condition.wait()
        }
    }
}

private extension OffMainParseRegressionTests {
    func makeLatchParser(latch: OffMainParseLatch) -> MarkdownParser {
        MarkdownParser { source in
            latch.wait()
            return MarkdownParser.live.parse(source)
        }
    }

    func makeQuillView(parser: MarkdownParser) -> QuillView {
        let renderConfiguration = RenderConfiguration(
            streamingMode: .smoothedTail,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .init(heightMeasurementCoalescingInterval: 0.005),
            bufferedStream: .default
        )

        let configuration = QuillConfiguration(
            streaming: .init(mode: .smoothedTail, preset: .balanced),
            renderConfiguration: renderConfiguration
        )

        let renderer = makeDocumentRenderer()
        let streamCoordinator = StreamCoordinator(
            renderer: renderer,
            renderConfiguration: renderConfiguration,
            bufferedStreamCommitScheduler: .live,
            bufferedVisualFeeder: .init(),
            streamController: MarkdownStreamController.init
        )

        let dependencies = QuillView.Dependencies(
            heightCoordinator: HeightCoordinator(),
            markdownParser: parser,
            streamCoordinator: streamCoordinator
        )

        let view = QuillView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 0),
            configuration: configuration,
            dependencies: dependencies
        )
        view.layoutIfNeeded()
        return view
    }

    func renderedDocumentText(from view: QuillView) -> String? {
        view.firstDocumentTextView()?.contentStorage?.attributedString?.string
    }

    // Larger than QuillView.synchronousInitialParseThreshold (16 KB) so renderStatic takes the
    // async/off-main parse path these tests exercise. With ≤16 KB content (Issue 01 sync-parse) the
    // blocking latch parser would run on the main actor and deadlock the test.
    func makeLargeStaticMarkdown(marker: String) -> String {
        var markdown = "# \(marker)\n\n"
        var index = 0
        while markdown.utf8.count <= 16_384 {
            markdown += "## \(marker) section \(index)\n\n"
                + "Paragraph \(index) body text for the \(marker) document with enough length to grow.\n\n"
            index += 1
        }
        return markdown
    }
}
