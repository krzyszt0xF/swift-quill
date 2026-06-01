import QuillKit
import UIKit

/// Default syntax highlighter wrapping HighlighterSwift.
public struct SyntaxHighlighter: SyntaxHighlighting, Sendable {
    private let engine: HighlightEngine

    init(engine: HighlightEngine) {
        self.engine = engine
    }

    public func highlight(code: String, language: String) -> NSAttributedString? {
        engine.highlight(code: code, language: language, userInterfaceStyle: .unspecified)
    }

    public func highlight(
        code: String,
        language: String,
        userInterfaceStyle: UIUserInterfaceStyle
    ) -> NSAttributedString? {
        engine.highlight(code: code, language: language, userInterfaceStyle: userInterfaceStyle)
    }
}

public extension SyntaxHighlighter {
    static let `default` = SyntaxHighlighter(engine: .default)
}
