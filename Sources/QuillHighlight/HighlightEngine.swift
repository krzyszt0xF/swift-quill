import Highlighter
import UIKit

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
