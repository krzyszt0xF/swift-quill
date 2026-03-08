@testable import QuillKit
import Testing
import UIKit

@MainActor
@Suite("CodeBlockView")
struct CodeBlockViewTests {
    @Test("Can be instantiated")
    func canBeInstantiated() {
        let view = CodeBlockView()
        #expect(view is UIView)
    }

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
