import UIKit

protocol CodeBlockHighlightSink: AnyObject {
    @MainActor func apply(highlightedCode: HighlightedCodeSnapshot)
}
