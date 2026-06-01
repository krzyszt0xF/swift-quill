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
    }

    func reset() {
        cancelAll()
        highlightStoreState.removeAll()
        cache.removeAllObjects()
    }

    func scheduleHighlight(
        blockID: BlockIdentity,
        code: String,
        language: String,
        userInterfaceStyle: UIUserInterfaceStyle = .unspecified
    ) {
        guard let highlighter else { return }

        let cacheKey = "\(userInterfaceStyle.rawValue):\(language):\(code)"
        if let cached = cache.object(forKey: cacheKey as NSString) {
            let snapshot = HighlightedCodeSnapshot(cached)
            let sink = highlightStoreState.storeResult(snapshot, for: blockID)
            sink?.apply(highlightedCode: snapshot)
            return
        }

        let requestID = UUID()
        pendingBlockRequests[blockID] = requestID

        highlightQueue.async {
            let result = highlighter.highlight(code: code, language: language, userInterfaceStyle: userInterfaceStyle)

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
        highlightStoreState.setPresentationEnabled(highlighter != nil)
        // Only drop in-flight requests when the highlighter is removed; SwiftUI re-applies the same
        // highlighter every updateUIView, and clearing here would orphan an in-flight static highlight.
        if highlighter == nil {
            pendingBlockRequests.removeAll()
        }
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

    // @unchecked Sendable: all mutable state (pendingResults, sinks) is serialized through `lock: NSLock`
    // via `lock.withLock { ... }` on every read and write — see every method on this class for the pattern.
    // The invariant to preserve in future edits is: never touch `pendingResults` or `sinks` outside a `lock.withLock` block.
    final class HighlightStoreState: @unchecked Sendable {
        private let lock = NSLock()
        private var pendingResults: [BlockIdentity: HighlightedCodeSnapshot] = [:]
        private var presentationEnabled = false
        private var sinks: [BlockIdentity: WeakSinkBox] = [:]

        func highlightedResult(for blockID: BlockIdentity) -> HighlightedCodeSnapshot? {
            lock.withLock {
                guard presentationEnabled else { return nil }

                return pendingResults[blockID]
            }
        }

        func registerSink(_ sink: any CodeBlockHighlightSink, for blockID: BlockIdentity) {
            lock.withLock {
                sinks[blockID] = WeakSinkBox(sink: sink)
            }
        }

        func setPresentationEnabled(_ enabled: Bool) {
            lock.withLock {
                presentationEnabled = enabled
            }
        }

        func removeAll() {
            lock.withLock {
                pendingResults.removeAll()
                sinks.removeAll()
            }
        }

        func storeResult(
            _ result: HighlightedCodeSnapshot,
            for blockID: BlockIdentity
        ) -> (any CodeBlockHighlightSink)? {
            lock.withLock {
                pendingResults[blockID] = result
                return sinks[blockID]?.sink
            }
        }

        func unregisterSink(for blockID: BlockIdentity) {
            _ = lock.withLock {
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
