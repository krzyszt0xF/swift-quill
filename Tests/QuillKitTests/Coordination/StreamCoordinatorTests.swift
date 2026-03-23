@testable import QuillKit
import Testing

@Suite("StreamCoordinator")
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

    @Test("Buffered visual feed keeps newline boundaries as separate chunks")
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
}
