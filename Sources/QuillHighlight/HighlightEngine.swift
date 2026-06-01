import Highlighter
import UIKit

// @unchecked Sendable: the wrapped `Highlighter` instances from HighlighterSwift are not Sendable. All
// access to them is serialized through `queue: DispatchQueue` via `queue.sync { ... }`. Each instance
// has its theme set ONCE at init and never again (HighlighterSwift's `setTheme` is not thread-safe), so
// we keep one instance per interface style and pick between them per pass. Invariant to preserve: never
// read or mutate the instances outside a `queue.sync` block.
final class HighlightEngine: @unchecked Sendable {
    private let queue: DispatchQueue
    private var darkInstance: Highlighter?
    private var lightInstance: Highlighter?

    init(
        queue: DispatchQueue,
        darkThemeName: String,
        lightThemeName: String,
        makeHighlighter: @escaping () -> Highlighter?
    ) {
        self.queue = queue
        queue.sync {
            let dark = makeHighlighter()
            dark?.setTheme(darkThemeName)
            self.darkInstance = dark

            let light = makeHighlighter()
            light?.setTheme(lightThemeName)
            self.lightInstance = light
        }
    }

    func highlight(
        code: String,
        language: String,
        userInterfaceStyle: UIUserInterfaceStyle
    ) -> NSAttributedString? {
        let normalizedKey = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedLanguage = SupportedLanguage(abbreviation: normalizedKey)?.normalized ?? normalizedKey
        return queue.sync {
            // Non-dark (including .unspecified) uses the light palette.
            let instance = userInterfaceStyle == .dark ? darkInstance : lightInstance
            return instance?.highlight(code, as: normalizedLanguage)
        }
    }
}

extension HighlightEngine {
    static let `default` = HighlightEngine(
        queue: .init(label: "com.quill.highlight.engine"),
        darkThemeName: "atom-one-dark",
        lightThemeName: "atom-one-light",
        makeHighlighter: Highlighter.init)
}
