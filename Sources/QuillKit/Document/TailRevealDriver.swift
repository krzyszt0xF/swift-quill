import QuartzCore

@MainActor
final class TailRevealDriver: NSObject {
    private var accumulatedTime: CFTimeInterval = 0
    private let canRevealMore: () -> Bool
    private let hasPresentationWork: () -> Bool
    private let intervalProvider: () -> TimeInterval
    private let updatePresentation: (CFTimeInterval) -> Void
    private let revealNextBatch: () -> Bool
    private var displayLink: CADisplayLink?

    init(
        canRevealMore: @escaping () -> Bool,
        hasPresentationWork: @escaping () -> Bool,
        intervalProvider: @escaping () -> TimeInterval,
        updatePresentation: @escaping (CFTimeInterval) -> Void,
        revealNextBatch: @escaping () -> Bool
    ) {
        self.canRevealMore = canRevealMore
        self.hasPresentationWork = hasPresentationWork
        self.intervalProvider = intervalProvider
        self.updatePresentation = updatePresentation
        self.revealNextBatch = revealNextBatch
        super.init()
    }

    var isRunning: Bool {
        displayLink != nil
    }

    func resume(immediate: Bool) {
        if immediate, canRevealMore() {
            _ = revealNextBatch()
        }

        guard canRevealMore() || hasPresentationWork() else {
            stop()
            return
        }

        if displayLink == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }
    }

    func stop() {
        accumulatedTime = 0
        displayLink?.invalidate()
        displayLink = nil
    }
}

private extension TailRevealDriver {
    @objc func handleDisplayLink(_ displayLink: CADisplayLink) {
        updatePresentation(displayLink.timestamp)

        accumulatedTime += displayLink.targetTimestamp - displayLink.timestamp
        let interval = max(0.016, intervalProvider())

        if accumulatedTime >= interval {
            while accumulatedTime >= interval, canRevealMore() {
                accumulatedTime -= interval
                guard revealNextBatch() else {
                    stop()
                    return
                }
            }
        }

        if canRevealMore() == false, hasPresentationWork() == false {
            stop()
        }
    }
}
