@testable import QuillKit
import QuillCore
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Selection gating during streaming", GloballySerialized())
struct SelectionGatingTests {
    @Test("frozenContentLength nil allows full document selection")
    func nilFrozenContentAllowsFullSelection() throws {
        let textView = DocumentTextView()
        let contentStorage = try #require(textView.contentStorage)
        textView.frozenContentLength = nil

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: 0),
                with: NSAttributedString(string: "Hello world")
            )
        }

        applySelectionChange(
            NSRange(location: 0, length: 11),
            to: textView
        )

        #expect(textView.selectedRange.length == 11)
    }

    @Test("frozenContentLength clamps selection extending past boundary")
    func clampsSelectionPastBoundary() throws {
        let textView = DocumentTextView()
        let contentStorage = try #require(textView.contentStorage)

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: 0),
                with: NSAttributedString(string: String(repeating: "x", count: 100))
            )
        }

        textView.frozenContentLength = 50
        applySelectionChange(
            NSRange(location: 30, length: 40),
            to: textView
        )

        #expect(textView.selectedRange.location == 30)
        #expect(textView.selectedRange.length == 20)
    }

    @Test("selection entirely within frozen content is not modified")
    func selectionWithinFrozenContentUnchanged() throws {
        let textView = DocumentTextView()
        let contentStorage = try #require(textView.contentStorage)

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: 0),
                with: NSAttributedString(string: String(repeating: "x", count: 100))
            )
        }

        textView.frozenContentLength = 80
        applySelectionChange(
            NSRange(location: 10, length: 20),
            to: textView
        )

        #expect(textView.selectedRange == NSRange(location: 10, length: 20))
    }

    @Test("selection starting past frozen boundary collapses to boundary")
    func selectionPastBoundaryCollapses() throws {
        let textView = DocumentTextView()
        let contentStorage = try #require(textView.contentStorage)

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: 0),
                with: NSAttributedString(string: String(repeating: "x", count: 100))
            )
        }

        textView.frozenContentLength = 50
        applySelectionChange(
            NSRange(location: 60, length: 10),
            to: textView
        )

        #expect(textView.selectedRange == NSRange(location: 50, length: 0))
    }

    @Test("updateSelectionGate sets frozen length during streaming")
    func updateSelectionGateSetsLength() throws {
        let renderer = DocumentRenderer.live
        renderer.textView.frame = CGRect(x: 0, y: 0, width: 320, height: 400)

        let blocks: [Block] = [
            .paragraph(content: [.text("Frozen paragraph")]),
            .paragraph(content: [.text("Mutable tail")]),
        ]
        renderer.render(blocks: blocks.makeNodes(), frozenCount: 1)
        renderer.updateSelectionGate(isStreaming: true)

        let document = try #require(renderer.textView.contentStorage?.attributedString)
        let expectedStart = (document.string as NSString).range(of: "Mutable tail").location

        #expect(renderer.textView.frozenContentLength == expectedStart)
    }

    @Test("updateSelectionGate clears frozen length when not streaming")
    func updateSelectionGateClearsLength() {
        let renderer = DocumentRenderer.live
        renderer.textView.frozenContentLength = 50
        renderer.updateSelectionGate(isStreaming: false)

        #expect(renderer.textView.frozenContentLength == nil)
    }
}

private extension SelectionGatingTests {
    func applySelectionChange(
        _ range: NSRange,
        to textView: DocumentTextView
    ) {
        textView.selectedRange = range
        textView.textViewDidChangeSelection(textView)
    }
}
