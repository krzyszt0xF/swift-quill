import QuillCore
import UIKit

@MainActor
final class HighlightCoordinator {
    private var highlighter: (any SyntaxHighlighting)?
    private let highlightQueue: DispatchQueue
    private var pendingBlockRequests: [BlockIdentity: UUID]
    private let cache: NSCache<NSString, NSAttributedString>
    private let highlightStoreState: HighlightStoreState

    init(cacheLimit: Int, highlightQueue: DispatchQueue) {
        self.highlightQueue = highlightQueue
        self.pendingBlockRequests = .init()
        self.cache = NSCache<NSString, NSAttributedString>()
        self.highlightStoreState = .init()
        self.cache.countLimit = cacheLimit
    }

    func cancelAll() {
        pendingBlockRequests.removeAll()
        highlightStoreState.removeAll()
    }

    func reset() {
        cancelAll()
        cache.removeAllObjects()
    }

    func scheduleHighlight(blockID: BlockIdentity, code: String, language: String) {
        guard let highlighter else { return }

        let cacheKey = "\(language):\(code)"
        if let cached = cache.object(forKey: cacheKey as NSString) {
            let snapshot = HighlightedCodeSnapshot(cached)
            let sink = highlightStoreState.storeResult(snapshot, for: blockID)
            sink?.apply(highlightedCode: snapshot)
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

    func set(highlighter: (any SyntaxHighlighting)?) {
        self.highlighter = highlighter
        cache.removeAllObjects()
        cancelAll()
    }
}

extension HighlightCoordinator: CodeBlockHighlightStore {
    nonisolated func highlightedResult(for blockID: BlockIdentity) -> HighlightedCodeSnapshot? {
        highlightStoreState.highlightedResult(for: blockID)
    }

    nonisolated func registerSink(_ sink: any CodeBlockHighlightSink, for blockID: BlockIdentity) {
        highlightStoreState.registerSink(sink, for: blockID)
    }

    nonisolated func unregisterSink(for blockID: BlockIdentity) {
        highlightStoreState.unregisterSink(for: blockID)
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

        let cachedResult = NSAttributedString(attributedString: result)
        let snapshot = HighlightedCodeSnapshot(cachedResult)
        cache.setObject(cachedResult, forKey: cacheKey as NSString)

        let sink = highlightStoreState.storeResult(snapshot, for: blockID)
        sink?.apply(highlightedCode: snapshot)
    }

    // Safety: all mutable state serialized through NSLock.
    final class HighlightStoreState: @unchecked Sendable {
        private let lock = NSLock()
        private var pendingResults: [BlockIdentity: HighlightedCodeSnapshot] = [:]
        private var sinks: [BlockIdentity: WeakSinkBox] = [:]

        func highlightedResult(for blockID: BlockIdentity) -> HighlightedCodeSnapshot? {
            lock.withLock {
                pendingResults[blockID]
            }
        }

        func registerSink(_ sink: any CodeBlockHighlightSink, for blockID: BlockIdentity) {
            lock.withLock {
                sinks[blockID] = WeakSinkBox(sink: sink)
            }
        }

        func removeAll() {
            lock.withLock {
                pendingResults.removeAll()
                sinks.removeAll()
            }
        }

        func storeResult(_ result: HighlightedCodeSnapshot, for blockID: BlockIdentity) -> (any CodeBlockHighlightSink)? {
            lock.withLock {
                pendingResults[blockID] = result
                return sinks[blockID]?.sink
            }
        }

        func unregisterSink(for blockID: BlockIdentity) {
            lock.withLock {
                sinks.removeValue(forKey: blockID)
            }
        }
    }

    final class WeakSinkBox {
        weak var sink: (any CodeBlockHighlightSink)?

        init(sink: any CodeBlockHighlightSink) {
            self.sink = sink
        }
    }
}
