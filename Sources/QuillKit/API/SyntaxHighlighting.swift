import UIKit

/// Consumer-provided syntax highlighter for code blocks.
public protocol SyntaxHighlighting: Sendable {
    func highlight(code: String, language: String) -> NSAttributedString?
}
