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

        _ = await waitUntil(timeoutMilliseconds: 400) {
            view.lastRevealedIndex > 5
        }
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

    @Test("Revealed characters fade from initial alpha to full alpha")
    func revealedCharactersFadeToFullAlpha() async throws {
        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        let baseColor = UIColor.systemBlue
        view.configure(
            with: NSAttributedString(
                string: "A",
                attributes: [.foregroundColor: baseColor]
            )
        )

        view.configureStreaming(
            with: NSAttributedString(
                string: "AB",
                attributes: [.foregroundColor: baseColor]
            ),
            charsPerStep: 1,
            baseDuration: 0.001,
            commaPause: 0,
            sentencePause: 0,
            revealInitialAlpha: 0.2,
            revealFadeDuration: 0.08
        )

        let revealCompleted = await waitUntil(timeoutMilliseconds: 400) {
            view.lastRevealedIndex == 2
        }
        #expect(revealCompleted)
        #expect(view.lastRevealedIndex == 2)

        let earlyColor = try #require(view.displayedForegroundColor(at: 1))
        #expect(earlyColor.cgColor.alpha >= 0.2)
        #expect(earlyColor.cgColor.alpha < 1.0)

        let reachedFullAlpha = await waitUntil(timeoutMilliseconds: 400) {
            guard let color = view.displayedForegroundColor(at: 1) else {
                return false
            }
            return abs(color.cgColor.alpha - 1.0) < 0.05
        }
        #expect(reachedFullAlpha)
        let finalColor = try #require(view.displayedForegroundColor(at: 1))
        #expect(abs(finalColor.cgColor.alpha - 1) < 0.05)
    }
}

private extension TextFlowViewStreamingTests {
    func wait(milliseconds: UInt64) async {
        try? await Task.sleep(for: .milliseconds(milliseconds))
    }

    func waitUntil(timeoutMilliseconds: UInt64, condition: @escaping () -> Bool) async -> Bool {
        let timeout = Duration.milliseconds(timeoutMilliseconds)
        let start = ContinuousClock.now
        while (ContinuousClock.now - start) < timeout {
            if condition() {
                return true
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }
}
