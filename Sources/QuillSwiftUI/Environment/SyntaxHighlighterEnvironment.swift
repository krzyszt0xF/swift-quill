import QuillKit
import SwiftUI

private struct SyntaxHighlighterKey: EnvironmentKey {
    static let defaultValue: (any SyntaxHighlighter)? = nil
}

extension EnvironmentValues {
    var quillSyntaxHighlighter: (any SyntaxHighlighter)? {
        get { self[SyntaxHighlighterKey.self] }
        set { self[SyntaxHighlighterKey.self] = newValue }
    }
}

public extension View {
    func quillSyntaxHighlighter(_ highlighter: (any SyntaxHighlighter)?) -> some View {
        environment(\.quillSyntaxHighlighter, highlighter)
    }
}
