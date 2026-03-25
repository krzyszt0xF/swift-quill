@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("CodeBlockView")
struct CodeBlockViewTests {
    private static let minimumVisibleHeight: CGFloat = 36
    private static let testWidth: CGFloat = 320

    @Test("applyHighlightedCode replaces code label content")
    func applyHighlightedCodeReplacesCodeLabelContent() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let highlighted = NSAttributedString(
            string: "let x = 1",
            attributes: [.foregroundColor: UIColor.red]
        )
        view.apply(highlightedCode: HighlightedCodeSnapshot(highlighted))

        let codeLabel = codeLabel(in: view)
        #expect(codeLabel?.attributedText?.string == "let x = 1")
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

    @Test("Configure trims trailing newline")
    func configureTrimsTrailingNewline() {
        let view = CodeBlockView()
        view.configure(language: nil, code: "line1\nline2\n")

        let codeLabel = codeLabel(in: view)
        #expect(codeLabel?.attributedText?.string == "line1\nline2")
    }

    @Test("Configure with language shows language pill")
    func configureWithLanguageShowsLanguagePill() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let languagePillLabel = findSubview(of: UILabel.self, in: view, matching: { $0.text == "swift" })
        #expect(languagePillLabel != nil)
        #expect(languagePillLabel?.isHidden == false)
    }

    @Test("Configure with nil language hides language pill")
    func configureWithNilLanguageHidesLanguagePill() {
        let view = CodeBlockView()
        view.configure(language: nil, code: "code")

        let languagePillLabel = findSubview(
            of: UILabel.self,
            in: view,
            matching: { $0.text == nil || $0.text?.isEmpty != false }
        )
        #expect(languagePillLabel?.isHidden == true)
    }

    @Test("Copy button is wired to copy action")
    func copyButtonIsWiredToCopyAction() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let button = findSubview(of: UIButton.self, in: view)
        #expect(button != nil)
        #expect(view.currentCode == "let x = 1")

        let actions = button?.actions(forTarget: view, forControlEvent: .touchUpInside)
        #expect(actions?.isEmpty == false)
    }

    @Test("Code block view does not install long press gestures")
    func codeBlockViewDoesNotInstallLongPressGestures() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let hasLongPressGesture = view.gestureRecognizers?.contains { $0 is UILongPressGestureRecognizer } ?? false
        #expect(hasLongPressGesture == false)
    }

    @Test("Header bar visible with language")
    func headerBarVisibleWithLanguage() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let languageLabel = findSubview(of: UILabel.self, in: view, matching: { $0.text == "swift" })
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

        let copyButton = findSubview(of: UIButton.self, in: view)
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

        let languagePillLabel = findSubview(of: UILabel.self, in: view, matching: { $0.text == "json" })
        let codeLabel = codeLabel(in: view)

        #expect(languagePillLabel != nil)
        #expect(codeLabel != nil)

        if let languagePillLabel, let codeLabel {
            let pillFrame = view.convert(languagePillLabel.bounds, from: languagePillLabel)
            let textFrame = view.convert(codeLabel.bounds, from: codeLabel)
            #expect(textFrame.minY >= pillFrame.maxY)
        }
    }

    @Test("setStreamingState false enables copy button")
    func setStreamingStateFalseEnablesCopyButton() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")
        view.setStreamingState(true)
        view.setStreamingState(false)

        let button = findSubview(of: UIButton.self, in: view)
        #expect(button?.isEnabled == true)
    }

    @Test("setStreamingState true disables copy button")
    func setStreamingStateTrueDisablesCopyButton() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")
        view.setStreamingState(true)

        let button = findSubview(of: UIButton.self, in: view)
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
}

private extension CodeBlockViewTests {
    func codeLabel(in view: CodeBlockView) -> UILabel? {
        findSubview(of: UILabel.self, in: view, matching: { $0.numberOfLines == 0 })
    }
}
