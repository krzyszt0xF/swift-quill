@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("CodeBlockView")
struct CodeBlockViewTests {
    private static let minimumVisibleHeight: CGFloat = 36
    private static let testWidth: CGFloat = 320

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

    @Test("Configure trims trailing newline")
    func configureTrimsTrailingNewline() {
        let view = CodeBlockView()
        view.configure(language: nil, code: "line1\nline2\n")

        let codeTextView = findSubview(of: UITextView.self, in: view)
        #expect(codeTextView?.text == "line1\nline2")
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
        let codeTextView = findSubview(of: UITextView.self, in: view)

        #expect(languagePillLabel != nil)
        #expect(codeTextView != nil)

        if let languagePillLabel, let codeTextView {
            let pillFrame = view.convert(languagePillLabel.bounds, from: languagePillLabel)
            let textFrame = view.convert(codeTextView.bounds, from: codeTextView)
            #expect(textFrame.minY >= pillFrame.maxY)
        }
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
