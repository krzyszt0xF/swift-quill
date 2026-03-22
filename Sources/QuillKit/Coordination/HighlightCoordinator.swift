import QuillCore
import UIKit

@MainActor
final class HighlightCoordinator {
    private(set) var pendingResults: [BlockIdentity: NSAttributedString] = [:]

    private var highlighter: (any SyntaxHighlighter)?
    private let highlightQueue: DispatchQueue
    private var pendingBlockRequests: [BlockIdentity: UUID]
    private let cache: NSCache<NSString, NSAttributedString>

    init(cacheLimit: Int, highlightQueue: DispatchQueue) {
        self.highlightQueue = highlightQueue
        self.pendingBlockRequests = .init()
        self.cache = NSCache<NSString, NSAttributedString>()
        self.cache.countLimit = cacheLimit
    }

    func cancelAll() {
        pendingBlockRequests.removeAll()
        pendingResults.removeAll()
    }

    func consumePendingResult(for blockID: BlockIdentity) -> NSAttributedString? {
        pendingResults.removeValue(forKey: blockID)
    }

    func reset() {
        cancelAll()
        cache.removeAllObjects()
    }

    func scheduleHighlight(blockID: BlockIdentity, code: String, language: String) {
        guard let highlighter else { return }

        let cacheKey = "\(language):\(code)"
        if let cached = cache.object(forKey: cacheKey as NSString) {
            pendingResults[blockID] = cached
            return
        }

        let requestID = UUID()
        pendingBlockRequests[blockID] = requestID

        highlightQueue.async {
            let result = highlighter.highlight(code: code, language: language)

            Task { @MainActor [weak self] in
                self?.applyBlockHighlightResult(
                    result,
                    blockID: blockID,
                    requestID: requestID,
                    cacheKey: cacheKey
                )
            }
        }
    }

    func set(highlighter: (any SyntaxHighlighter)?) {
        self.highlighter = highlighter
        cache.removeAllObjects()
        cancelAll()
    }
}

extension HighlightCoordinator {
    static var live: Self {
        Self(
            cacheLimit: 50,
            highlightQueue: DispatchQueue(
                label: "com.quill.highlight",
                qos: .userInitiated
            )
        )
    }
}

private extension HighlightCoordinator {
    func applyBlockHighlightResult(
        _ result: NSAttributedString?,
        blockID: BlockIdentity,
        requestID: UUID,
        cacheKey: String
    ) {
        guard pendingBlockRequests[blockID] == requestID else { return }

        pendingBlockRequests.removeValue(forKey: blockID)

        guard let result else { return }

        cache.setObject(result, forKey: cacheKey as NSString)
        pendingResults[blockID] = result
    }
}
