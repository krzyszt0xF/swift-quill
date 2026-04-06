import QuillCore
import UIKit

@MainActor
final class ImageLoadingCoordinator {
    var onAspectRatioChanged: (() -> Void)?
    var imageAppearance: ImageAppearance { appearance }

    private var appearance: ImageAppearance
    private let cache: NSCache<NSURL, UIImage>
    private var loader: (any ImageLoading)?
    private var pendingURLTasks: [URL: Task<Void, Never>]
    private var sourceURLByBlockID: [BlockIdentity: URL]
    private let storeState: ImageStoreState
    private var waitingBlockIDsByURL: [URL: Set<BlockIdentity>]

    init(cacheLimit: Int = 50, appearance: ImageAppearance = .default) {
        self.appearance = appearance
        self.cache = NSCache<NSURL, UIImage>()
        self.loader = nil
        self.pendingURLTasks = [:]
        self.sourceURLByBlockID = [:]
        self.storeState = .init()
        self.waitingBlockIDsByURL = [:]
        self.cache.countLimit = cacheLimit
    }

    func cancelAll() {
        for task in pendingURLTasks.values {
            task.cancel()
        }

        pendingURLTasks.removeAll()
        sourceURLByBlockID.removeAll()
        storeState.removeAll()
        waitingBlockIDsByURL.removeAll()
    }

    func reset() {
        cancelAll()
        cache.removeAllObjects()
    }

    func scheduleLoad(blockID: BlockIdentity, source: String?) {
        detach(blockID: blockID)
        storeState.removeState(for: blockID)

        guard
            let loader,
            let source,
            let url = makeLoadURL(from: source)
        else {
            storeFailure(for: blockID)
            return
        }

        if let cachedImage = cache.object(forKey: url as NSURL) {
            let aspectRatioDidChange = storeLoadedImage(cachedImage, for: blockID)
            if aspectRatioDidChange {
                onAspectRatioChanged?()
            }
            return
        }

        waitingBlockIDsByURL[url, default: []].insert(blockID)
        sourceURLByBlockID[blockID] = url

        guard pendingURLTasks[url] == nil else { return }

        pendingURLTasks[url] = Task(priority: .userInitiated) { [weak self, loader] in
            do {
                let image = try await loader.loadImage(from: url)
                self?.applyLoadedImage(image, for: url)
            } catch is CancellationError {
                self?.finishCancelledLoad(for: url)
            } catch {
                self?.applyFailedLoad(for: url)
            }
        }
    }

    func set(loader: (any ImageLoading)?) {
        self.loader = loader
        cache.removeAllObjects()
        cancelAll()
    }

    func set(options: ImageOptions) {
        appearance = options.appearance
        storeState.setRetryEnabled(options.retryEnabled)
    }
}

extension ImageLoadingCoordinator: ImageLoadStore {
    nonisolated func loadResult(for blockID: BlockIdentity) -> ImageLoadResult? {
        storeState.loadResult(for: blockID)
    }

    nonisolated func register(sink: any ImageLoadSink, for blockID: BlockIdentity) {
        storeState.register(sink: sink, for: blockID)
    }

    nonisolated func resolvedAspectRatio(for blockID: BlockIdentity) -> CGFloat? {
        storeState.resolvedAspectRatio(for: blockID)
    }

    nonisolated var retryEnabled: Bool {
        storeState.retryEnabled
    }

    nonisolated func retryLoad(blockID: BlockIdentity, source: String?) {
        Task { @MainActor [weak self] in
            self?.scheduleLoad(blockID: blockID, source: source)
        }
    }

    nonisolated func unregisterSink(for blockID: BlockIdentity) {
        storeState.unregisterSink(for: blockID)
    }
}

extension ImageLoadingCoordinator {
    static var live: Self {
        Self()
    }
}

private extension ImageLoadingCoordinator {
    func applyFailedLoad(for url: URL) {
        pendingURLTasks.removeValue(forKey: url)

        let waitingBlockIDs = waitingBlockIDsByURL.removeValue(forKey: url) ?? []
        for blockID in waitingBlockIDs {
            sourceURLByBlockID.removeValue(forKey: blockID)
            storeFailure(for: blockID)
        }
    }

    func applyLoadedImage(_ image: UIImage, for url: URL) {
        pendingURLTasks.removeValue(forKey: url)
        cache.setObject(image, forKey: url as NSURL)

        let waitingBlockIDs = waitingBlockIDsByURL.removeValue(forKey: url) ?? []
        var invalidatedAspectRatio = false
        for blockID in waitingBlockIDs {
            sourceURLByBlockID.removeValue(forKey: blockID)
            invalidatedAspectRatio = storeLoadedImage(image, for: blockID) || invalidatedAspectRatio
        }

        if invalidatedAspectRatio {
            onAspectRatioChanged?()
        }
    }

    func detach(blockID: BlockIdentity) {
        guard let previousURL = sourceURLByBlockID.removeValue(forKey: blockID) else { return }

        waitingBlockIDsByURL[previousURL]?.remove(blockID)
        if waitingBlockIDsByURL[previousURL]?.isEmpty == true {
            waitingBlockIDsByURL.removeValue(forKey: previousURL)
            pendingURLTasks.removeValue(forKey: previousURL)?.cancel()
        }
    }

    func finishCancelledLoad(for url: URL) {
        pendingURLTasks.removeValue(forKey: url)
    }

    func makeAspectRatio(for image: UIImage) -> CGFloat? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        return image.size.width / image.size.height
    }

    func makeLoadURL(from source: String) -> URL? {
        guard
            let url = URL(string: source),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            url.host?.isEmpty == false
        else {
            return nil
        }

        return url
    }

    func storeFailure(for blockID: BlockIdentity) {
        storeState.removeState(for: blockID)
        let sink = storeState.storeResult(.failed, for: blockID)
        sink?.apply(imageLoadResult: .failed)
    }

    @discardableResult
    func storeLoadedImage(_ image: UIImage, for blockID: BlockIdentity) -> Bool {
        let aspectRatio = makeAspectRatio(for: image)
        let result = ImageLoadResult.loaded(image)
        let sink = storeState.storeResult(result, for: blockID)
        if let aspectRatio {
            storeState.storeAspectRatio(aspectRatio, for: blockID)
        }
        sink?.apply(imageLoadResult: result)
        guard let aspectRatio else { return false }
        return abs(aspectRatio - appearance.fallbackAspectRatio) > .ulpOfOne
    }

    final class ImageStoreState: @unchecked Sendable {
        private let lock = NSLock()
        private var aspectRatios: [BlockIdentity: CGFloat] = [:]
        private var results: [BlockIdentity: ImageLoadResult] = [:]
        private var retryEnabledValue = true
        private var sinks: [BlockIdentity: WeakSinkBox] = [:]

        func loadResult(for blockID: BlockIdentity) -> ImageLoadResult? {
            lock.withLock {
                results[blockID]
            }
        }

        func register(sink: any ImageLoadSink, for blockID: BlockIdentity) {
            lock.withLock {
                sinks[blockID] = WeakSinkBox(sink: sink)
            }
        }

        var retryEnabled: Bool {
            lock.withLock {
                retryEnabledValue
            }
        }

        func removeAll() {
            lock.withLock {
                aspectRatios.removeAll()
                results.removeAll()
                sinks.removeAll()
            }
        }

        func removeState(for blockID: BlockIdentity) {
            lock.withLock {
                aspectRatios.removeValue(forKey: blockID)
                results.removeValue(forKey: blockID)
            }
        }

        func resolvedAspectRatio(for blockID: BlockIdentity) -> CGFloat? {
            lock.withLock {
                aspectRatios[blockID]
            }
        }

        func setRetryEnabled(_ retryEnabled: Bool) {
            lock.withLock {
                retryEnabledValue = retryEnabled
            }
        }

        func storeAspectRatio(_ aspectRatio: CGFloat, for blockID: BlockIdentity) {
            lock.withLock {
                aspectRatios[blockID] = aspectRatio
            }
        }

        func storeResult(
            _ result: ImageLoadResult,
            for blockID: BlockIdentity
        ) -> (any ImageLoadSink)? {
            lock.withLock {
                results[blockID] = result
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
        weak var sink: (any ImageLoadSink)?

        init(sink: any ImageLoadSink) {
            self.sink = sink
        }
    }
}
