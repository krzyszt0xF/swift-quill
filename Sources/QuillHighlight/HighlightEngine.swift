import Highlighter
import UIKit

// @unchecked Sendable: the wrapped `Highlighter` instance from HighlighterSwift is not Sendable. All
// access to `instance` is serialized through `queue: DispatchQueue` via `queue.sync { ... }` in both
// `init` and `highlight(code:language:)`. The invariant to preserve in future edits is: never read or
// mutate `instance` outside a `queue.sync` block.
final class HighlightEngine: @unchecked Sendable {
    private let queue: DispatchQueue
    private var instance: Highlighter?

    init(
        queue: DispatchQueue,
        themeName: String,
        makeHighlighter: @escaping () -> Highlighter?
    ) {
        self.queue = queue
        queue.sync {
            let highlighter = makeHighlighter()
            highlighter?.setTheme(themeName)
            self.instance = highlighter
        }
    }

    func highlight(code: String, language: String) -> NSAttributedString? {
        let normalizedKey = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedLanguage = SupportedLanguage(abbreviation: normalizedKey)?.normalized ?? normalizedKey
        return queue.sync {
            instance?.highlight(code, as: normalizedLanguage)
        }
    }
}

extension HighlightEngine {
    static let `default` = HighlightEngine(
        queue: .init(label: "com.quill.highlight.engine"),
        themeName: "atom-one-dark",
        makeHighlighter: Highlighter.init)
}
