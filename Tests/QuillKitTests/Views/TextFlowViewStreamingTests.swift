import QuillCore
@testable import QuillKit
import QuillSharedTestSupport
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

        let revealAdvanced = await eventually(timeout: .milliseconds(400)) {
            view.lastRevealedIndex > 5
        }
        #expect(revealAdvanced)
        #expect(view.lastRevealedIndex < 11)

        view.finishReveal()
        #expect(view.lastRevealedIndex == 11)
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

        let revealStarted = await eventually(timeout: .milliseconds(240)) {
            view.lastRevealedIndex > 5
        }
        #expect(revealStarted)
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

        await wait(for: .milliseconds(80))
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

        let revealStarted = await eventually(timeout: .milliseconds(120)) {
            view.lastRevealedIndex > 5
        }
        #expect(revealStarted)
    }

    @Test("Hidden backlog does not expand layout before reveal")
    func hiddenBacklogDoesNotExpandLayoutBeforeReveal() async {
        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 140, height: 0))
        view.configure(with: NSAttributedString(string: "Short line"))
        view.layoutIfNeeded()

        let initialHeight = view.intrinsicContentSize.height

        view.configureStreaming(
            with: NSAttributedString(string: "Short line\nThis line should appear later\nAnd this one later too"),
            charsPerStep: 1,
            baseDuration: 0.050,
            commaPause: 0,
            sentencePause: 0
        )
        view.layoutIfNeeded()

        let hiddenBacklogHeight = view.intrinsicContentSize.height
        #expect(hiddenBacklogHeight == initialHeight)

        let revealAdvanced = await eventually(timeout: .milliseconds(400)) {
            view.lastRevealedIndex > 10
        }
        #expect(revealAdvanced)

        view.layoutIfNeeded()
        #expect(view.intrinsicContentSize.height > hiddenBacklogHeight)
    }

    @Test("Structural markers are visible and occupy layout before text reveal")
    func structuralMarkersOccupyInitialLayout() {
        let items = [
            Block.ListItem(children: [.paragraph(content: [.text("hello world")])]),
        ]
        let block = Block.unorderedList(items: items)
        let segment = RenderNode.FlowSegment(blocks: [block])
        let attributedString = AttributedStringBuilder.build(from: segment)

        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.configureStreaming(
            with: attributedString,
            charsPerStep: 1,
            baseDuration: 10,
            commaPause: 0,
            sentencePause: 0
        )
        view.layoutIfNeeded()

        let marker = "+\t"
        for index in 0..<marker.count {
            #expect(view.displayedForegroundColor(at: index) != UIColor.clear)
        }
        #expect(view.intrinsicContentSize.height > 0)
        #expect(view.lastRevealedIndex == marker.count)
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

        let revealCompleted = await eventually(timeout: .milliseconds(400)) {
            view.lastRevealedIndex == 2
        }
        #expect(revealCompleted)
        #expect(view.lastRevealedIndex == 2)

        let earlyColor = try #require(view.displayedForegroundColor(at: 1))
        #expect(earlyColor.cgColor.alpha >= 0.2)
        #expect(earlyColor.cgColor.alpha < 1.0)

        let reachedFullAlpha = await eventually(timeout: .milliseconds(400)) {
            guard let displayedColor = view.displayedForegroundColor(at: 1) else {
                return false
            }
            return abs(displayedColor.cgColor.alpha - 1.0) < 0.05
        }
        #expect(reachedFullAlpha)

        let finalColor = try #require(view.displayedForegroundColor(at: 1))
        #expect(abs(finalColor.cgColor.alpha - 1) < 0.05)
    }
}
