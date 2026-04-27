@testable import QuillKit
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("CodeBlockView", GloballySerialized(), .tags(.rendering))
struct CodeBlockViewTests {
    private static let minimumVisibleHeight: CGFloat = 36
    private static let testWidth: CGFloat = 320

    @Test("applyHighlightedCode replaces code text view content")
    func applyHighlightedCodeReplacesCodeTextViewContent() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let highlighted = NSAttributedString(
            string: "let x = 1",
            attributes: [.foregroundColor: UIColor.red]
        )
        view.apply(highlightedCode: HighlightedCodeSnapshot(highlighted))

        let codeTextView = codeTextView(in: view)
        #expect(codeTextView?.attributedText?.string == "let x = 1")
    }

    @Test("applyHighlightedCode preserves syntax colors")
    func applyHighlightedCodePreservesSyntaxColors() throws {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let highlighted = NSMutableAttributedString(string: "let x = 1")
        highlighted.addAttribute(
            .foregroundColor,
            value: UIColor.systemRed,
            range: NSRange(location: 0, length: 3)
        )

        view.apply(highlightedCode: HighlightedCodeSnapshot(highlighted))

        let textView = try #require(codeTextView(in: view))
        let foregroundColor = textView.attributedText?.attribute(
            .foregroundColor,
            at: 1,
            effectiveRange: nil
        ) as? UIColor
        #expect(foregroundColor == UIColor.systemRed)
    }

    @Test("Configured code block keeps visible fitting height")
    func configuredCodeBlockKeepsVisibleFittingHeight() {
        let view = CodeBlockView()
        view.configure(language: "json", code: "{ \"stream\": true, \"chunks\": 42 }\n")

        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: Self.testWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        #expect(fittingSize.height > Self.minimumVisibleHeight)
    }

    @Test("Configure invalidates measured height when code changes")
    func configureInvalidatesMeasuredHeight() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")
        let initialHeight = view.intrinsicContentSize.height

        view.configure(
            language: "swift",
            code: """
            let x = 1
            let y = 2
            let z = 3
            """
        )

        #expect(view.intrinsicContentSize.height > initialHeight)
    }

    @Test("Configure preserves trailing newline")
    func configurePreservesTrailingNewline() {
        let view = CodeBlockView()
        view.configure(language: nil, code: "line1\nline2\n")

        let codeTextView = codeTextView(in: view)
        #expect(codeTextView?.attributedText?.string == "line1\nline2\n")
    }

    @Test("Configure with language shows language pill")
    func configureWithLanguageShowsLanguagePill() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let languagePillLabel: UILabel? = view.firstSubview(where: { $0.text == "swift" })
        #expect(languagePillLabel != nil)
        #expect(languagePillLabel?.isHidden == false)
    }

    @Test("Configure with nil language hides language pill")
    func configureWithNilLanguageHidesLanguagePill() {
        let view = CodeBlockView()
        view.configure(language: nil, code: "code")

        let languagePillLabel: UILabel? = view.firstSubview(
            where: { $0.text == nil || $0.text?.isEmpty != false }
        )
        #expect(languagePillLabel?.isHidden == true)
    }

    @Test("Copy button is wired to copy action")
    func copyButtonIsWiredToCopyAction() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let button: UIButton? = view.firstSubview()
        #expect(button != nil)
        #expect(view.currentCode == "let x = 1")

        let actions = button?.actions(forTarget: view, forControlEvent: .touchUpInside)
        #expect(actions?.isEmpty == false)
    }

    @Test("copy button uses injected onCopy closure")
    func copyButtonUsesInjectedOnCopyClosure() {
        let view = CodeBlockView()
        var copiedText: String?
        view.onCopy = { copiedText = $0 }
        view.configure(language: "swift", code: "let x = 1")

        view.perform(NSSelectorFromString("copyTapped"))

        #expect(copiedText == "let x = 1")
    }

    @Test("Code block view does not install long press gestures")
    func codeBlockViewDoesNotInstallLongPressGestures() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let hasLongPressGesture = view.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer } ?? false
        #expect(hasLongPressGesture == false)
    }

    @Test("Code text view is selectable and not scrollable")
    func codeTextViewSupportsSelection() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let codeTextView = codeTextView(in: view)

        #expect(codeTextView?.isEditable == false)
        #expect(codeTextView?.isScrollEnabled == false)
        #expect(codeTextView?.isSelectable == true)
    }

    @Test("Header bar visible with language")
    func headerBarVisibleWithLanguage() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let languageLabel: UILabel? = view.firstSubview(where: { $0.text == "swift" })
        #expect(languageLabel != nil)
        #expect(languageLabel?.isHidden == false)

        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: Self.testWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        #expect(fittingSize.height > Self.minimumVisibleHeight)
    }

    @Test("Header bar visible without language")
    func headerBarVisibleWithoutLanguage() {
        let view = CodeBlockView()
        view.configure(language: nil, code: "plain code")

        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: Self.testWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        #expect(fittingSize.height > Self.minimumVisibleHeight)

        let copyButton: UIButton? = view.firstSubview()
        #expect(copyButton != nil)
    }

    @Test("Language pill does not overlap code content")
    func languagePillDoesNotOverlapCodeContent() {
        let view = CodeBlockView()
        view.configure(language: "json", code: "{ \"stream\": true, \"chunks\": 42 }\n")

        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: Self.testWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        view.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: fittingSize.height)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        let languagePillLabel: UILabel? = view.firstSubview(where: { $0.text == "json" })
        let codeTextView = codeTextView(in: view)

        #expect(languagePillLabel != nil)
        #expect(codeTextView != nil)

        if let languagePillLabel, let codeTextView {
            let pillFrame = view.convert(languagePillLabel.bounds, from: languagePillLabel)
            let textFrame = view.convert(codeTextView.bounds, from: codeTextView)
            #expect(textFrame.minY >= pillFrame.maxY)
        }
    }

    @Test("setStreamingState false enables copy button")
    func setStreamingStateFalseEnablesCopyButton() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")
        view.setStreamingState(true)
        view.setStreamingState(false)

        let button: UIButton? = view.firstSubview()
        #expect(button?.isEnabled == true)
    }

    @Test("setStreamingState true disables copy button")
    func setStreamingStateTrueDisablesCopyButton() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")
        view.setStreamingState(true)

        let button: UIButton? = view.firstSubview()
        #expect(button?.isEnabled == false)
    }

    @Test("sizeThatFits returns visible height for manual container measurement")
    func sizeThatFitsReturnsVisibleHeight() {
        let view = CodeBlockView()
        view.configure(language: "json", code: "{ \"stream\": true, \"chunks\": 42 }\n")

        let fittingSize = view.sizeThatFits(CGSize(width: Self.testWidth, height: CGFloat.greatestFiniteMagnitude))

        #expect(fittingSize.width == Self.testWidth)
        #expect(fittingSize.height > Self.minimumVisibleHeight)
    }

    @Test("Highlighted code preserves text selection")
    func highlightedCodePreservesTextSelection() throws {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let value = 123")

        let textView = try #require(codeTextView(in: view))
        textView.selectedRange = NSRange(location: 4, length: 5)

        let highlighted = NSAttributedString(
            string: "let value = 123",
            attributes: [.foregroundColor: UIColor.red]
        )
        view.apply(highlightedCode: HighlightedCodeSnapshot(highlighted))

        #expect(textView.selectedRange == NSRange(location: 4, length: 5))
    }

    @Test("Highlighted code preserves trailing newline")
    func highlightedCodePreservesTrailingNewline() throws {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let value = 123\n")

        let highlighted = NSAttributedString(
            string: "let value = 123",
            attributes: [.foregroundColor: UIColor.red]
        )
        view.apply(highlightedCode: HighlightedCodeSnapshot(highlighted))

        let textView = try #require(codeTextView(in: view))
        #expect(textView.attributedText?.string == "let value = 123\n")
    }

    @Test("Highlighted code preserves measured height")
    func highlightedCodePreservesMeasuredHeight() {
        let view = CodeBlockView()
        view.configure(
            language: "swift",
            code: """
            let value = 123
            let nextValue = 456
            """
        )
        let initialHeight = view.intrinsicContentSize.height

        let highlighted = NSAttributedString(
            string: """
            let value = 123
            let nextValue = 456
            """,
            attributes: [.foregroundColor: UIColor.red]
        )
        view.apply(highlightedCode: HighlightedCodeSnapshot(highlighted))

        #expect(view.intrinsicContentSize.height == initialHeight)
    }

    @Test("Selected fragment exposes copy action")
    func selectedFragmentExposesCopyAction() throws {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let value = 123")

        let textView = try #require(codeTextView(in: view))
        textView.selectedRange = NSRange(location: 4, length: 5)

        #expect(textView.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil))
    }

    @Test("Highlighted code preserves horizontal scroll offset")
    func highlightedCodePreservesHorizontalScrollOffset() throws {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let someVeryLongValueName = anotherVeryLongValueName")
        view.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: 120)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        let scrollView = try #require(codeScrollView(in: view))
        scrollView.contentOffset = CGPoint(x: 32, y: 0)

        let highlighted = NSAttributedString(
            string: "let someVeryLongValueName = anotherVeryLongValueName",
            attributes: [.foregroundColor: UIColor.red]
        )
        view.apply(highlightedCode: HighlightedCodeSnapshot(highlighted))

        #expect(scrollView.contentOffset.x == 32)
    }

    @Test("Wide code block keeps horizontal-only scroll content")
    func wideCodeBlockKeepsHorizontalOnlyScrollContent() throws {
        let view = CodeBlockView()
        view.configure(
            language: "md",
            code: """
            #### Line Breaks
            * `---`
            #### Vertical Rule
            * `|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|`
            """
        )

        let fittingSize = view.sizeThatFits(
            CGSize(width: Self.testWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        view.frame = CGRect(x: 0, y: 0, width: Self.testWidth, height: fittingSize.height)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        let scrollView = try #require(codeScrollView(in: view))

        #expect(scrollView.contentSize.width > scrollView.bounds.width)
        #expect(abs(scrollView.contentSize.height - scrollView.bounds.height) <= 1)
    }
}

private extension CodeBlockViewTests {
    func codeScrollView(in view: CodeBlockView) -> UIScrollView? {
        view.firstSubview(where: { $0 !== view })
    }

    func codeTextView(in view: CodeBlockView) -> UITextView? {
        view.firstSubview(where: { $0.isSelectable && $0.isEditable == false })
    }
}
