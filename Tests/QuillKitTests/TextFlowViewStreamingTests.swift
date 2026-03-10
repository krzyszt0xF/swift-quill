@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("TextFlowView Streaming")
struct TextFlowViewStreamingTests {
    @Test("Append updates reveal progressively instead of replacing immediately")
    func appendUpdatesRevealProgressively() async {
        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.configure(with: NSAttributedString(string: "Hello"))

        view.configureStreaming(
            with: NSAttributedString(string: "Hello world"),
            charsPerStep: 1,
            baseDuration: 0.100,
            commaPause: 0,
            sentencePause: 0
        )

        #expect(view.lastRevealedIndex == 5)

        await wait(milliseconds: 140)
        #expect(view.lastRevealedIndex > 5)
        #expect(view.lastRevealedIndex < 11)

        view.finishReveal()
        #expect(view.lastRevealedIndex == 11)
    }

    @Test("Prefix mismatch falls back to immediate full update")
    func prefixMismatchFallsBackToImmediateUpdate() {
        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.configure(with: NSAttributedString(string: "Hello"))

        view.configureStreaming(
            with: NSAttributedString(string: "Jello"),
            charsPerStep: 1,
            baseDuration: 0.100,
            commaPause: 0,
            sentencePause: 0
        )

        #expect(view.lastRevealedIndex == 5)
    }

    @Test("Buffered streaming waits for backlog before starting reveal")
    func bufferedStreamingWaitsForBacklog() async {
        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.configure(with: NSAttributedString(string: "Hello"))

        view.configureStreaming(
            with: NSAttributedString(string: "Hello world"),
            charsPerStep: 1,
            baseDuration: 0.010,
            commaPause: 0,
            sentencePause: 0,
            startBufferCharacters: 20,
            maxStartDelay: 0.200
        )

        await wait(milliseconds: 80)
        #expect(view.lastRevealedIndex == 5)

        view.configureStreaming(
            with: NSAttributedString(string: "Hello world, this now has enough buffered text."),
            charsPerStep: 1,
            baseDuration: 0.010,
            commaPause: 0,
            sentencePause: 0,
            startBufferCharacters: 20,
            maxStartDelay: 0.200
        )

        await wait(milliseconds: 80)
        #expect(view.lastRevealedIndex > 5)
    }

    @Test("Buffered streaming starts after max delay when backlog stays below threshold")
    func bufferedStreamingStartsAfterMaxDelay() async {
        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.configure(with: NSAttributedString(string: "Hello"))

        view.configureStreaming(
            with: NSAttributedString(string: "Hello world"),
            charsPerStep: 1,
            baseDuration: 0.010,
            commaPause: 0,
            sentencePause: 0,
            startBufferCharacters: 100,
            maxStartDelay: 0.050
        )

        #expect(view.lastRevealedIndex == 5)
        await wait(milliseconds: 240)
        #expect(view.lastRevealedIndex > 5)
    }
}

private extension TextFlowViewStreamingTests {
    func wait(milliseconds: UInt64) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }
}
