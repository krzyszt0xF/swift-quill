import UIKit

/// Consumer-provided syntax highlighter for code blocks.
public protocol SyntaxHighlighter: Sendable {
    func highlight(code: String, language: String) -> NSAttributedString?
}
