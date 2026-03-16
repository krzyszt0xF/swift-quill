import QuillCore
@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("TextFlowView Links")
struct TextFlowViewLinkTests {
    @Test("handleTap fires callback for visible link")
    func handleTapFiresCallback() {
        let view = makeConfiguredView(
            from: segment(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))
        )
        var tappedURL: URL?

        view.onLinkTap = { url in
            tappedURL = url
        }
        view.handleTap(at: CGPoint(x: 8, y: midLineY(in: view)))

        #expect(tappedURL == URL(string: "https://example.com"))
    }

    @Test("linkURL rejects empty trailing line space")
    func linkURLRejectsTrailingLineSpace() {
        let view = makeConfiguredView(
            from: segment(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))
        )

        let url = view.linkURL(at: CGPoint(x: view.bounds.width - 4, y: midLineY(in: view)))
        #expect(url == nil)
    }

    @Test("linkURL returns nil for non-link text")
    func linkURLReturnsNilForPlainText() {
        let view = makeConfiguredView(
            from: segment(.paragraph(content: [.text("plain text")]))
        )

        let url = view.linkURL(at: CGPoint(x: 8, y: midLineY(in: view)))
        #expect(url == nil)
    }

    @Test("bare URL in text is tappable")
    func bareURLInTextIsTappable() {
        let view = makeConfiguredView(
            from: segment(.paragraph(content: [.text("See https://developer.apple.com/documentation for docs")]))
        )

        let url = view.linkURL(at: CGPoint(x: 64, y: midLineY(in: view)))
        #expect(url == URL(string: "https://developer.apple.com/documentation"))
    }

    @Test("streaming hidden link stays inert until revealed")
    func streamingHiddenLinkStaysInertUntilRevealed() {
        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        let attributedString = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))
        )

        view.configure(with: NSAttributedString(string: ""))
        view.configureStreaming(
            with: attributedString,
            charsPerStep: 1,
            baseDuration: 10,
            commaPause: 0,
            sentencePause: 0
        )
        view.layoutIfNeeded()

        let hiddenURL = view.linkURL(at: CGPoint(x: 8, y: 1))
        #expect(hiddenURL == nil)

        _ = view.revealCharacters(upTo: 2)
        view.layoutIfNeeded()

        let revealedURL = view.linkURL(at: CGPoint(x: 8, y: midLineY(in: view)))
        #expect(revealedURL == URL(string: "https://example.com"))
    }

    @Test("streaming visible link stays tappable after full reveal")
    func streamingVisibleLinkStaysTappableAfterFullReveal() {
        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        let attributedString = AttributedStringBuilder.build(
            from: segment(.paragraph(content: [.link(destination: "https://example.com", children: [.text("click")])]))
        )

        view.configure(with: NSAttributedString(string: ""))
        view.configureStreaming(
            with: attributedString,
            charsPerStep: 1,
            baseDuration: 10,
            commaPause: 0,
            sentencePause: 0
        )
        _ = view.revealCharacters(upTo: attributedString.length)
        view.layoutIfNeeded()

        let url = view.linkURL(at: CGPoint(x: 8, y: midLineY(in: view)))
        #expect(url == URL(string: "https://example.com"))
    }
}

private extension TextFlowViewLinkTests {
    func makeConfiguredView(from segment: RenderNode.FlowSegment) -> TextFlowView {
        let view = TextFlowView(frame: CGRect(x: 0, y: 0, width: 320, height: 0))
        view.configure(with: AttributedStringBuilder.build(from: segment))
        view.layoutIfNeeded()
        return view
    }

    func midLineY(in view: TextFlowView) -> CGFloat {
        max(1, view.intrinsicContentSize.height / 2)
    }

    func segment(_ blocks: Block...) -> RenderNode.FlowSegment {
        RenderNode.FlowSegment(blocks: Array(blocks))
    }
}
