import UIKit

/// Consumer-provided syntax highlighter for code blocks.
public protocol SyntaxHighlighting: Sendable {
    func highlight(code: String, language: String) -> NSAttributedString?

    func highlight(code: String, language: String, userInterfaceStyle: UIUserInterfaceStyle) -> NSAttributedString?
}

public extension SyntaxHighlighting {
    func highlight(code: String, language: String, userInterfaceStyle: UIUserInterfaceStyle) -> NSAttributedString? {
        highlight(code: code, language: language)
    }
}
