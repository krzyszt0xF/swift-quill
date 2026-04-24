@testable import QuillKit
import QuillCore
import QuillSharedTestSupport
import Testing
import UIKit

@MainActor
@Suite("ImageLoadingCoordinator", .tags(.rendering))
struct ImageLoadingCoordinatorTests {
    @Test("scheduleLoad with valid URL stores loaded result and notifies sink")
    func scheduleLoadStoresLoadedResult() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let blockID = BlockIdentity(rawValue: 1)
        let sink = MockImageLoadSink()
        let url = URL(string: "https://example.com/image.png")!
        let image = makeImage(width: 120, height: 60)

        coordinator.set(loader: loader)
        coordinator.register(sink: sink, for: blockID)
        await loader.resolve(.success(image), for: url)

        coordinator.scheduleLoad(blockID: blockID, source: url.absoluteString)

        let rendered = await eventually {
            sink.loadedImageSize == image.size
        }

        #expect(rendered)
        #expect(coordinator.loadResult(for: blockID).isLoadedImage)
    }

    @Test("scheduleLoad with cached URL does not invoke loader again")
    func scheduleLoadUsesCache() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let firstBlockID = BlockIdentity(rawValue: 1)
        let secondBlockID = BlockIdentity(rawValue: 2)
        let firstSink = MockImageLoadSink()
        let secondSink = MockImageLoadSink()
        let url = URL(string: "https://example.com/cached.png")!
        let image = makeImage(width: 200, height: 100)

        coordinator.set(loader: loader)
        await loader.resolve(.success(image), for: url)
        coordinator.register(sink: firstSink, for: firstBlockID)
        coordinator.scheduleLoad(blockID: firstBlockID, source: url.absoluteString)

        let firstRendered = await eventually {
            firstSink.loadedImageSize == image.size
        }
        #expect(firstRendered)
        #expect(await loader.callCount(for: url) == 1)

        coordinator.register(sink: secondSink, for: secondBlockID)
        coordinator.scheduleLoad(blockID: secondBlockID, source: url.absoluteString)

        #expect(secondSink.loadedImageSize == image.size)
        #expect(await loader.callCount(for: url) == 1)
    }

    @Test("scheduleLoad with nil loader stores failed result")
    func scheduleLoadWithoutLoaderFails() {
        let coordinator = ImageLoadingCoordinator()
        let blockID = BlockIdentity(rawValue: 3)
        let sink = MockImageLoadSink()

        coordinator.register(sink: sink, for: blockID)
        coordinator.scheduleLoad(
            blockID: blockID,
            source: "https://example.com/missing-loader.png"
        )

        #expect(sink.failureCount == 1)
        #expect(coordinator.loadResult(for: blockID).isFailure == true)
    }

    @Test("scheduleLoad with invalid source stores failed result")
    func scheduleLoadWithInvalidSourceFails() {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let blockID = BlockIdentity(rawValue: 4)
        let sink = MockImageLoadSink()

        coordinator.set(loader: loader)
        coordinator.register(sink: sink, for: blockID)
        coordinator.scheduleLoad(blockID: blockID, source: "%%not-a-url%%")

        #expect(sink.failureCount == 1)
        #expect(coordinator.loadResult(for: blockID).isFailure == true)
    }

    @Test("cancelAll cancels pending loads and clears stored state")
    func cancelAllCancelsPendingLoads() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let blockID = BlockIdentity(rawValue: 5)
        let sink = MockImageLoadSink()
        let url = URL(string: "https://example.com/cancel.png")!
        let image = makeImage(width: 80, height: 40)

        coordinator.set(loader: loader)
        coordinator.register(sink: sink, for: blockID)
        coordinator.scheduleLoad(blockID: blockID, source: url.absoluteString)

        let started = await eventually {
            await loader.callCount(for: url) == 1
        }
        #expect(started)

        coordinator.cancelAll()
        await loader.resolve(.success(image), for: url)
        await wait(for: .milliseconds(50))

        #expect(sink.results.isEmpty)
        #expect(coordinator.loadResult(for: blockID) == nil)
    }

    @Test("cancelAll keeps loaded image result and clears pending bookkeeping")
    func cancelAllKeepsLoadedImageResult() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let loadedBlockID = BlockIdentity(rawValue: 200)
        let pendingBlockID = BlockIdentity(rawValue: 201)
        let loadedSink = MockImageLoadSink()
        let pendingSink = MockImageLoadSink()
        let loadedURL = URL(string: "https://example.com/keep-loaded.png")!
        let pendingURL = URL(string: "https://example.com/still-pending.png")!
        let image = makeImage(width: 50, height: 50)

        coordinator.set(loader: loader)
        coordinator.register(sink: loadedSink, for: loadedBlockID)
        await loader.resolve(.success(image), for: loadedURL)
        coordinator.scheduleLoad(blockID: loadedBlockID, source: loadedURL.absoluteString)

        let loaded = await eventually { loadedSink.loadedImageSize == image.size }
        #expect(loaded)

        coordinator.register(sink: pendingSink, for: pendingBlockID)
        coordinator.scheduleLoad(blockID: pendingBlockID, source: pendingURL.absoluteString)

        let pendingStarted = await eventually { await loader.callCount(for: pendingURL) == 1 }
        #expect(pendingStarted)

        coordinator.cancelAll()

        #expect(coordinator.loadResult(for: loadedBlockID).isLoadedImage)

        await loader.resolve(.success(image), for: pendingURL)
        await wait(for: .milliseconds(50))

        #expect(pendingSink.results.isEmpty)
        #expect(coordinator.loadResult(for: pendingBlockID) == nil)
    }

    @Test("reset clears loaded image result and pending bookkeeping")
    func resetClearsLoadedImageResult() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let blockID = BlockIdentity(rawValue: 210)
        let sink = MockImageLoadSink()
        let url = URL(string: "https://example.com/reset-clear.png")!
        let image = makeImage(width: 50, height: 50)

        coordinator.set(loader: loader)
        coordinator.register(sink: sink, for: blockID)
        await loader.resolve(.success(image), for: url)
        coordinator.scheduleLoad(blockID: blockID, source: url.absoluteString)

        let loaded = await eventually { sink.loadedImageSize == image.size }
        #expect(loaded)

        coordinator.reset()

        #expect(coordinator.loadResult(for: blockID) == nil)
    }

    @Test("reset clears cache so subsequent load re-invokes loader")
    func resetClearsCache() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let firstBlockID = BlockIdentity(rawValue: 6)
        let secondBlockID = BlockIdentity(rawValue: 7)
        let firstSink = MockImageLoadSink()
        let secondSink = MockImageLoadSink()
        let url = URL(string: "https://example.com/reset.png")!
        let image = makeImage(width: 90, height: 45)

        coordinator.set(loader: loader)
        await loader.resolve(.success(image), for: url)
        coordinator.register(sink: firstSink, for: firstBlockID)
        coordinator.scheduleLoad(blockID: firstBlockID, source: url.absoluteString)

        let firstRendered = await eventually {
            firstSink.loadedImageSize == image.size
        }
        #expect(firstRendered)
        #expect(await loader.callCount(for: url) == 1)

        coordinator.reset()
        coordinator.register(sink: secondSink, for: secondBlockID)
        coordinator.scheduleLoad(blockID: secondBlockID, source: url.absoluteString)

        let secondRendered = await eventually {
            secondSink.loadedImageSize == image.size
        }
        #expect(secondRendered)
        #expect(await loader.callCount(for: url) == 2)
    }

    @Test("retryLoad reissues request after failure")
    func retryLoadReissuesRequest() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let blockID = BlockIdentity(rawValue: 8)
        let sink = MockImageLoadSink()
        let url = URL(string: "https://example.com/retry.png")!
        let image = makeImage(width: 110, height: 55)

        coordinator.set(loader: loader)
        coordinator.register(sink: sink, for: blockID)
        await loader.resolve(.failure(MockError.failed), for: url)

        coordinator.scheduleLoad(blockID: blockID, source: url.absoluteString)

        let failed = await eventually {
            sink.failureCount == 1
        }
        #expect(failed)

        await loader.resolve(.success(image), for: url)
        coordinator.retryLoad(blockID: blockID, source: url.absoluteString)

        let retried = await eventually {
            sink.loadedImageSize == image.size
        }
        #expect(retried)
        #expect(await loader.callCount(for: url) == 2)
    }

    @Test("failed URL is not cached and next schedule retries")
    func failedURLIsNotCached() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let firstBlockID = BlockIdentity(rawValue: 81)
        let secondBlockID = BlockIdentity(rawValue: 82)
        let firstSink = MockImageLoadSink()
        let secondSink = MockImageLoadSink()
        let url = URL(string: "https://example.com/retry-next.png")!
        let image = makeImage(width: 110, height: 55)

        coordinator.set(loader: loader)
        coordinator.register(sink: firstSink, for: firstBlockID)
        await loader.resolve(.failure(MockError.failed), for: url)
        coordinator.scheduleLoad(blockID: firstBlockID, source: url.absoluteString)

        let firstFailed = await eventually {
            firstSink.failureCount == 1
        }
        #expect(firstFailed)
        #expect(await loader.callCount(for: url) == 1)

        coordinator.register(sink: secondSink, for: secondBlockID)
        await loader.resolve(.success(image), for: url)
        coordinator.scheduleLoad(blockID: secondBlockID, source: url.absoluteString)

        let retried = await eventually {
            secondSink.loadedImageSize == image.size
        }
        #expect(retried)
        #expect(await loader.callCount(for: url) == 2)
    }

    @Test("dedup shares one underlying load for multiple block IDs")
    func dedupSharesUnderlyingLoad() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let firstBlockID = BlockIdentity(rawValue: 9)
        let secondBlockID = BlockIdentity(rawValue: 10)
        let firstSink = MockImageLoadSink()
        let secondSink = MockImageLoadSink()
        let url = URL(string: "https://example.com/shared.png")!
        let image = makeImage(width: 300, height: 150)

        coordinator.set(loader: loader)
        coordinator.register(sink: firstSink, for: firstBlockID)
        coordinator.register(sink: secondSink, for: secondBlockID)

        coordinator.scheduleLoad(blockID: firstBlockID, source: url.absoluteString)
        coordinator.scheduleLoad(blockID: secondBlockID, source: url.absoluteString)

        let started = await eventually {
            await loader.callCount(for: url) == 1
        }
        #expect(started)

        await loader.resolve(.success(image), for: url)

        let delivered = await eventually {
            firstSink.loadedImageSize == image.size && secondSink.loadedImageSize == image.size
        }
        #expect(delivered)
        #expect(await loader.callCount(for: url) == 1)
    }

    @Test("set loader preserves cached image results")
    func setLoaderPreservesCachedImageResults() async {
        let coordinator = ImageLoadingCoordinator()
        let firstLoader = MockImageLoader()
        let secondLoader = MockImageLoader()
        let firstBlockID = BlockIdentity(rawValue: 101)
        let secondBlockID = BlockIdentity(rawValue: 102)
        let firstSink = MockImageLoadSink()
        let secondSink = MockImageLoadSink()
        let url = URL(string: "https://example.com/preserve-cache.png")!
        let image = makeImage(width: 300, height: 150)

        coordinator.set(loader: firstLoader)
        coordinator.register(sink: firstSink, for: firstBlockID)
        await firstLoader.resolve(.success(image), for: url)
        coordinator.scheduleLoad(blockID: firstBlockID, source: url.absoluteString)

        let firstRendered = await eventually {
            firstSink.loadedImageSize == image.size
        }
        #expect(firstRendered)
        #expect(await firstLoader.callCount(for: url) == 1)

        coordinator.set(loader: secondLoader)
        coordinator.register(sink: secondSink, for: secondBlockID)
        coordinator.scheduleLoad(blockID: secondBlockID, source: url.absoluteString)

        #expect(secondSink.loadedImageSize == image.size)
        #expect(await secondLoader.callCount(for: url) == 0)
    }

    @Test("set loader leaves in flight request on original loader")
    func setLoaderLeavesInFlightRequestOnOriginalLoader() async {
        let coordinator = ImageLoadingCoordinator()
        let firstLoader = MockImageLoader()
        let secondLoader = MockImageLoader()
        let blockID = BlockIdentity(rawValue: 103)
        let sink = MockImageLoadSink()
        let url = URL(string: "https://example.com/in-flight.png")!
        let image = makeImage(width: 80, height: 40)

        coordinator.set(loader: firstLoader)
        coordinator.register(sink: sink, for: blockID)
        coordinator.scheduleLoad(blockID: blockID, source: url.absoluteString)

        let started = await eventually {
            await firstLoader.callCount(for: url) == 1
        }
        #expect(started)

        coordinator.set(loader: secondLoader)
        await firstLoader.resolve(.success(image), for: url)

        let delivered = await eventually {
            sink.loadedImageSize == image.size
        }
        #expect(delivered)
        #expect(await secondLoader.callCount(for: url) == 0)
    }

    @Test("same block ID rescheduled with different URL keeps only latest result")
    func sameBlockIDRescheduledUsesLatestURL() async {
        let coordinator = ImageLoadingCoordinator()
        let loader = MockImageLoader()
        let blockID = BlockIdentity(rawValue: 11)
        let sink = MockImageLoadSink()
        let oldURL = URL(string: "https://example.com/old.png")!
        let newURL = URL(string: "https://example.com/new.png")!
        let oldImage = makeImage(width: 40, height: 20)
        let newImage = makeImage(width: 160, height: 80)

        coordinator.set(loader: loader)
        coordinator.register(sink: sink, for: blockID)
        coordinator.scheduleLoad(blockID: blockID, source: oldURL.absoluteString)

        let oldStarted = await eventually {
            await loader.callCount(for: oldURL) == 1
        }
        #expect(oldStarted)

        await loader.resolve(.success(newImage), for: newURL)
        coordinator.scheduleLoad(blockID: blockID, source: newURL.absoluteString)

        let latestDelivered = await eventually {
            sink.loadedImageSize == newImage.size
        }
        #expect(latestDelivered)

        await loader.resolve(.success(oldImage), for: oldURL)
        await wait(for: .milliseconds(50))

        #expect(sink.loadedImageSize == newImage.size)
        #expect(sink.loadedImageCount == 1)
    }

    @Test("aspect ratio callback fires only when geometry changes relative to fallback")
    func aspectRatioCallbackFiresOnlyForGeometryChange() async {
        let changingCoordinator = ImageLoadingCoordinator()
        let changingLoader = MockImageLoader()
        let changingURL = URL(string: "https://example.com/wide.png")!
        let changedImage = makeImage(width: 200, height: 100)
        var changedCount = 0

        changingCoordinator.set(loader: changingLoader)
        changingCoordinator.onAspectRatioChanged = { changedCount += 1 }
        await changingLoader.resolve(.success(changedImage), for: changingURL)
        changingCoordinator.scheduleLoad(
            blockID: BlockIdentity(rawValue: 12),
            source: changingURL.absoluteString
        )

        let changed = await eventually {
            changedCount == 1
        }
        #expect(changed)

        let matchingCoordinator = ImageLoadingCoordinator()
        let matchingLoader = MockImageLoader()
        let matchingURL = URL(string: "https://example.com/match.png")!
        let matchingImage = makeImage(width: 160, height: 90)
        var unchangedCount = 0

        var theme = QuillTheme.default
        theme.image.fallbackAspectRatio = 16.0 / 9.0
        matchingCoordinator.apply(theme: theme.image, retryEnabled: true)
        matchingCoordinator.set(loader: matchingLoader)
        matchingCoordinator.onAspectRatioChanged = { unchangedCount += 1 }
        await matchingLoader.resolve(.success(matchingImage), for: matchingURL)
        matchingCoordinator.scheduleLoad(
            blockID: BlockIdentity(rawValue: 13),
            source: matchingURL.absoluteString
        )

        await wait(for: .milliseconds(50))
        #expect(unchangedCount == 0)
    }
}

private extension ImageLoadingCoordinatorTests {
    enum MockError: Error {
        case failed
    }

    @MainActor
    final class MockImageLoadSink: ImageLoadSink {
        private(set) var results: [ImageLoadResult] = []

        var failureCount: Int {
            results.reduce(into: 0) { count, result in
                if case .failed = result {
                    count += 1
                }
            }
        }

        var loadedImageCount: Int {
            results.reduce(into: 0) { count, result in
                if case .loaded = result {
                    count += 1
                }
            }
        }

        var loadedImageSize: CGSize? {
            for result in results.reversed() {
                if case let .loaded(image) = result {
                    return image.size
                }
            }
            return nil
        }

        func apply(imageLoadResult: ImageLoadResult) {
            results.append(imageLoadResult)
        }
    }

    final class MockImageLoader: ImageLoading, @unchecked Sendable {
        private let lock = NSLock()
        private var callURLs: [URL] = []
        private var immediateResults: [URL: Result<UIImage, Error>] = [:]
        private var pendingContinuations: [URL: [CheckedContinuation<UIImage, Error>]] = [:]

        func loadImage(from url: URL) async throws -> UIImage {
            return try await withCheckedThrowingContinuation { continuation in
                let result: Result<UIImage, Error>? = lock.withLock {
                    callURLs.append(url)

                    if let result = immediateResults[url] {
                        return result
                    }

                    pendingContinuations[url, default: []].append(continuation)
                    return nil
                }

                if let result {
                    continuation.resume(with: result)
                }
            }
        }

        func callCount(for url: URL) async -> Int {
            lock.withLock {
                callURLs.filter { $0 == url }.count
            }
        }

        func resolve(_ result: Result<UIImage, Error>, for url: URL) async {
            let continuations: [CheckedContinuation<UIImage, Error>] = lock.withLock {
                immediateResults[url] = result
                return pendingContinuations.removeValue(forKey: url) ?? []
            }

            for continuation in continuations {
                continuation.resume(with: result)
            }
        }
    }

    func makeImage(
        width: CGFloat,
        height: CGFloat,
        color: UIColor = .systemBlue
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}

private extension ImageLoadResult? {
    var isFailure: Bool {
        switch self {
        case .some(.failed):
            return true
        default:
            return false
        }
    }

    var isLoadedImage: Bool {
        switch self {
        case .some(.loaded):
            return true
        default:
            return false
        }
    }
}
