@testable import QuillKit
import QuillCore
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("Document text view copy", GloballySerialized())
struct DocumentTextViewCopyTests {
    @Test("makeSelectionPlainText replaces attachment character with plain text")
    func replacesAttachmentCharacter() {
        let textView = DocumentTextView()
        let attributed = NSMutableAttributedString(string: "\u{FFFC}")
        attributed.addAttribute(
            .attachmentPlainText,
            value: "let x = 1",
            range: NSRange(location: 0, length: 1)
        )

        let result = textView.makeSelectionPlainText(from: attributed)

        #expect(result == "let x = 1")
    }

    @Test("makeSelectionPlainText preserves regular text")
    func preservesRegularText() {
        let textView = DocumentTextView()
        let attributed = NSAttributedString(string: "Hello world")

        let result = textView.makeSelectionPlainText(from: attributed)

        #expect(result == "Hello world")
    }

    @Test("makeSelectionPlainText handles mixed flow and attachment content")
    func mixedFlowAndAttachment() {
        let textView = DocumentTextView()
        let attributed = NSMutableAttributedString()
        attributed.append(NSAttributedString(string: "Before "))

        let attachment = NSMutableAttributedString(string: "\u{FFFC}")
        attachment.addAttribute(
            .attachmentPlainText,
            value: "code_here",
            range: NSRange(location: 0, length: 1)
        )
        attributed.append(attachment)
        attributed.append(NSAttributedString(string: " after"))

        let result = textView.makeSelectionPlainText(from: attributed)

        #expect(result == "Before code_here after")
    }

    @Test("makeSelectionPlainText handles multiple attachments")
    func multipleAttachments() {
        let textView = DocumentTextView()
        let attributed = NSMutableAttributedString()

        let codeAttachment = NSMutableAttributedString(string: "\u{FFFC}")
        codeAttachment.addAttribute(
            .attachmentPlainText,
            value: "func foo()",
            range: NSRange(location: 0, length: 1)
        )
        attributed.append(codeAttachment)
        attributed.append(NSAttributedString(string: "\n"))

        let imageAttachment = NSMutableAttributedString(string: "\u{FFFC}")
        imageAttachment.addAttribute(
            .attachmentPlainText,
            value: "screenshot",
            range: NSRange(location: 0, length: 1)
        )
        attributed.append(imageAttachment)

        let result = textView.makeSelectionPlainText(from: attributed)

        #expect(result == "func foo()\nscreenshot")
    }

    @Test("copy override produces attachment-aware plain text via onCopy")
    func copyOverrideProducesAttachmentAwarePlainText() throws {
        let textView = DocumentTextView()
        let contentStorage = try #require(textView.contentStorage)
        var copiedText: String?
        textView.onCopy = { copiedText = $0 }

        let content = NSMutableAttributedString(string: "Paragraph\n")
        let attachment = NSMutableAttributedString(string: "\u{FFFC}")
        attachment.addAttribute(
            .attachmentPlainText,
            value: "raw code",
            range: NSRange(location: 0, length: 1)
        )
        content.append(attachment)

        contentStorage.performEditingTransaction {
            contentStorage.textStorage?.replaceCharacters(
                in: NSRange(location: 0, length: 0),
                with: content
            )
        }

        textView.selectedRange = NSRange(location: 0, length: content.length)
        textView.copy(nil)

        #expect(copiedText == "Paragraph\nraw code")
    }
}
