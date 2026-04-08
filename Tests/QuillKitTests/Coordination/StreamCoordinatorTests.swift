import QuillCore
import QuillSharedTestSupport
@testable import QuillKit
import Testing

@MainActor @Suite("StreamCoordinator", .tags(.rendering, .streaming))
struct StreamCoordinatorTests {
    @Test("Buffered visual feed chunks preserve the original module text")
    func bufferedVisualFeedChunksPreserveModuleText() {
        let configuration = RenderConfiguration(
            streamingMode: .bufferedModules,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .default,
            bufferedStream: .default
        )
        let module = "# Title\n\nPewnego razu było sobie małe słoneczko.\n\n"

        let chunks = BufferedVisualFeeder.makeVisualFeedChunks(
            from: module,
            policy: configuration.tailReveal
        )

        #expect(chunks.count > 1)
        #expect(chunks.joined() == module)
    }

    @MainActor @Test("Buffered visual feed keeps newline boundaries as separate chunks")
    func bufferedVisualFeedChunksKeepNewlineBoundaries() {
        let configuration = RenderConfiguration(
            streamingMode: .bufferedModules,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .default,
            bufferedStream: .default
        )
        let module = "Line one\nLine two\n\n"

        let chunks = BufferedVisualFeeder.makeVisualFeedChunks(
            from: module,
            policy: configuration.tailReveal
        )

        #expect(chunks.contains("\n"))
        #expect(chunks.joined() == module)
    }

    @Test("Buffered visual feed splits long flushed tail into multiple chunks")
    func bufferedVisualFeedChunksSplitLongFlushedTail() {
        let configuration = RenderConfiguration(
            streamingMode: .bufferedModules,
            performanceProfile: .balanced,
            tailReveal: .balanced.scaled(by: 0.55),
            layout: .default,
            bufferedStream: .init(
                minModuleLength: 120,
                maxBufferingDelay: 1.2
            )
        )
        let flushedTail = """
        #### Line Breaks
        * `---`
        #### Bold
        * `**bold**`
        #### Italic
        * `_italic_`
        #### Underline
        * `__underline__`
        #### Strikethrough
        * `~~strikethrough~~`
        #### Horizontal Rule
        * `------`
        """

        let chunks = BufferedVisualFeeder.makeVisualFeedChunks(
            from: flushedTail,
            policy: configuration.tailReveal
        )

        #expect(chunks.count > 8)
        #expect(chunks.joined() == flushedTail)
    }

    @Test("Immediate feed keeps single-line chunks intact")
    func immediateFeedKeepsSingleLineChunksIntact() {
        let configuration = RenderConfiguration(
            streamingMode: .smoothedTail,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .default,
            bufferedStream: .default
        )
        let chunk = "Single line tail update"

        let chunks = BufferedVisualFeeder.makeImmediateFeedChunks(
            from: chunk,
            policy: configuration.tailReveal
        )

        #expect(chunks == [chunk])
    }

    @Test("Immediate feed splits multiline chunks for smoother structural streaming")
    func immediateFeedSplitsMultilineChunks() {
        let configuration = RenderConfiguration(
            streamingMode: .smoothedTail,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .default,
            bufferedStream: .default
        )
        let chunk = "```\ncode\n```\n- after\n"

        let chunks = BufferedVisualFeeder.makeImmediateFeedChunks(
            from: chunk,
            policy: configuration.tailReveal
        )

        #expect(chunks.count > 1)
        #expect(chunks.joined() == chunk)
        #expect(chunks.contains("\n"))
    }

    @MainActor
    @Test("Finish flushes pending buffered content into the stream")
    func finishFlushesPendingBufferedContent() async throws {
        let renderer = makeDocumentRenderer()
        let renderConfiguration = RenderConfiguration(
            streamingMode: .bufferedModules,
            performanceProfile: .balanced,
            tailReveal: .balanced,
            layout: .default,
            bufferedStream: .init(
                minModuleLength: 200,
                maxBufferingDelay: 10
            )
        )
        let configuration = QuillConfiguration(
            streaming: .init(mode: .bufferedModules, preset: .balanced),
            renderConfiguration: renderConfiguration
        )
        let coordinator = StreamCoordinator(
            renderer: renderer,
            renderConfiguration: renderConfiguration,
            bufferedStreamCommitScheduler: BufferedStreamCommitScheduler(
                moduleStreamGate: .init(),
                now: { 0 },
                sleep: { _ in }
            ),
            bufferedVisualFeeder: .init(),
            streamController: MarkdownStreamController.init
        )
        let pendingChunk = "Buffered content should remain pending until finish flushes the scheduler."

        coordinator.append(
            pendingChunk,
            currentMarkdown: nil,
            configuration: configuration,
            needsRestart: true
        )

        #expect(renderer.textView.contentStorage?.attributedString?.length ?? 0 == 0)

        coordinator.finish(configuration: configuration)

        let rendered = await eventually(timeout: .milliseconds(800)) {
            renderer.textView.contentStorage?.attributedString?.string.contains("Buffered content") == true
        }

        #expect(rendered)
    }
}
