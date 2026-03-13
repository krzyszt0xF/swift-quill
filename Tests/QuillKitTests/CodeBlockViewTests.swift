@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("CodeBlockView")
struct CodeBlockViewTests {
    @Test("Configure with language shows language pill")
    func configureWithLanguageShowsPill() {
        let view = CodeBlockView()
        view.configure(language: "swift", code: "let x = 1")

        let pill = findSubview(of: UILabel.self, in: view, matching: { $0.text == "swift" })
        #expect(pill != nil)
        #expect(pill?.isHidden == false)
    }

    @Test("Configure with nil language hides language pill")
    func configureWithNilLanguageHidesPill() {
        let view = CodeBlockView()
        view.configure(language: nil, code: "code")

        let pill = findSubview(of: UILabel.self, in: view, matching: { $0.text == nil || $0.text?.isEmpty != false })
        #expect(pill?.isHidden == true)
    }

    @Test("Configure trims trailing newline")
    func configureTrimsTrailingNewline() {
        let view = CodeBlockView()
        view.configure(language: nil, code: "line1\nline2\n")

        let textView = findSubview(of: UITextView.self, in: view)
        #expect(textView?.text == "line1\nline2")
    }

    @Test("Configured code block keeps visible fitting height")
    func configuredCodeBlockKeepsVisibleFittingHeight() {
        let view = CodeBlockView()
        view.configure(language: "json", code: "{ \"stream\": true, \"chunks\": 42 }\n")

        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: 320, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        #expect(fittingSize.height > 36)
    }

    @Test("sizeThatFits returns visible height for manual container measurement")
    func sizeThatFitsReturnsVisibleHeight() {
        let view = CodeBlockView()
        view.configure(language: "json", code: "{ \"stream\": true, \"chunks\": 42 }\n")

        let fittingSize = view.sizeThatFits(CGSize(width: 320, height: CGFloat.greatestFiniteMagnitude))

        #expect(fittingSize.width == 320)
        #expect(fittingSize.height > 36)
    }

    @Test("Language pill does not overlap code content")
    func languagePillDoesNotOverlapCodeContent() {
        let view = CodeBlockView()
        view.configure(language: "json", code: "{ \"stream\": true, \"chunks\": 42 }\n")

        let width: CGFloat = 320
        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        view.frame = CGRect(x: 0, y: 0, width: width, height: fittingSize.height)
        view.setNeedsLayout()
        view.layoutIfNeeded()

        let pill = findSubview(of: UILabel.self, in: view, matching: { $0.text == "json" })
        let textView = findSubview(of: UITextView.self, in: view)

        #expect(pill != nil)
        #expect(textView != nil)

        if let pill, let textView {
            let pillFrame = view.convert(pill.bounds, from: pill)
            let textFrame = view.convert(textView.bounds, from: textView)
            #expect(textFrame.minY >= pillFrame.maxY)
        }
    }
}

private extension CodeBlockViewTests {
    func findSubview<T: UIView>(of type: T.Type, in view: UIView, matching predicate: ((T) -> Bool)? = nil) -> T? {
        for subview in view.subviews {
            if let match = subview as? T, predicate?(match) ?? true {
                return match
            }
            if let found = findSubview(of: type, in: subview, matching: predicate) {
                return found
            }
        }
        return nil
    }
}
