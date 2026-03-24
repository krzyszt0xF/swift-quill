import QuillKit
import SwiftUI

private struct SyntaxHighlighterKey: EnvironmentKey {
    static let defaultValue: (any SyntaxHighlighting)? = nil
}

extension EnvironmentValues {
    var quillSyntaxHighlighter: (any SyntaxHighlighting)? {
        get { self[SyntaxHighlighterKey.self] }
        set { self[SyntaxHighlighterKey.self] = newValue }
    }
}

public extension View {
    func quillSyntaxHighlighter(_ highlighter: (any SyntaxHighlighting)?) -> some View {
        environment(\.quillSyntaxHighlighter, highlighter)
    }
}
