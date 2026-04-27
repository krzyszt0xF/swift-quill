@testable import QuillKit
import QuillCore
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("DocumentTextView", GloballySerialized(), .tags(.rendering))
struct DocumentTextViewTests {
    @Test("Link selection action handler forwards URL")
    func linkSelectionActionHandlerForwardsURL() {
        let textView = DocumentTextView()
        let url = URL(string: "https://example.com")!
        var selectedURL: URL?
        textView.onLinkSelection = { selectedURL = $0 }

        let handler = textView.makeLinkSelectionActionHandler(for: url)
        handler(UIAction(title: "Select") { _ in })

        #expect(selectedURL == url)
    }

    @Test("Text drag interaction is disabled")
    func textDragInteractionIsDisabled() {
        let textView = DocumentTextView()

        #expect(textView.textDragInteraction?.isEnabled == false)
    }

    @Test("Link selection callback overrides default interaction when installed")
    func linkSelectionCallbackOverridesDefaultInteraction() {
        let textView = DocumentTextView()
        let url = URL(string: "https://example.com")!
        var selectedURL: URL?
        textView.onLinkSelection = { selectedURL = $0 }

        let shouldInteract = textView.handleLinkSelection(url)

        #expect(shouldInteract == false)
        #expect(selectedURL == url)
    }

    @Test("Repeated layout with unchanged bounds does not recompute blockquote bars")
    func repeatedLayoutWithUnchangedBoundsDoesNotRecomputeBlockquoteBars() throws {
        let textView = DocumentTextView()
        let contentStorage = try #require(textView.contentStorage)
        let quotedText = NSMutableAttributedString(string: "Quoted")
        let range = NSRange(location: 0, length: quotedText.length)

        quotedText.addAttribute(.ownerBlockID, value: BlockIdentity(rawValue: 1), range: range)
        quotedText.addAttribute(.blockquoteDepth, value: 1, range: range)

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: 0),
                with: quotedText
            )
        }

        textView.frame = CGRect(x: 0, y: 0, width: 320, height: 80)
        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        textView.updateBlockquoteBarRunsIfNeeded()

        #expect(textView.blockquoteBarRunComputationCount == 1)

        textView.setNeedsLayout()
        textView.layoutIfNeeded()
        textView.updateBlockquoteBarRunsIfNeeded()

        #expect(textView.blockquoteBarRunComputationCount == 1)

        textView.handleDocumentContentChange()
        textView.updateBlockquoteBarRunsIfNeeded()

        #expect(textView.blockquoteBarRunComputationCount == 2)
    }

    @Test("copy uses injected onCopy closure")
    func copyUsesInjectedOnCopyClosure() throws {
        let textView = DocumentTextView()
        let contentStorage = try #require(textView.contentStorage)
        var copiedText: String?
        textView.onCopy = { copiedText = $0 }

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: 0),
                with: NSAttributedString(string: "Hello world")
            )
        }

        textView.selectedRange = NSRange(location: 0, length: 5)
        textView.copy(nil)

        #expect(copiedText == "Hello")
    }
}
