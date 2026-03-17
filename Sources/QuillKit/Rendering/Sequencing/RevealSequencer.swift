import UIKit

@MainActor
final class RevealSequencer {
    struct ResolvedTiming: Equatable, Sendable {
        var charsPerStep: Int
        var baseDuration: TimeInterval
        var elementGapDuration: TimeInterval
        var commaPause: TimeInterval
        var sentencePause: TimeInterval
        var jitterMax: TimeInterval

        init(
            charsPerStep: Int,
            baseDuration: TimeInterval,
            elementGapDuration: TimeInterval,
            commaPause: TimeInterval,
            sentencePause: TimeInterval,
            jitterMax: TimeInterval
        ) {
            self.charsPerStep = max(1, charsPerStep)
            self.baseDuration = max(0.001, baseDuration)
            self.elementGapDuration = max(0, elementGapDuration)
            self.commaPause = max(0, commaPause)
            self.sentencePause = max(0, sentencePause)
            self.jitterMax = max(0, jitterMax)
        }
    }

    var onComplete: (() -> Void)?
    var onLayoutChange: ((UIView?) -> Void)?
    private var isRunning = false

    private var blockRevealTask: Task<Void, Never>?
    private weak var blockRevealView: UIView?
    private var blockRevealStartTime: TimeInterval = 0
    private var currentTask: RevealTaskQueue.AnimationTask?
    private var currentTaskToken: UUID?
    private var currentTiming: ResolvedTiming
    private var taskQueue = RevealTaskQueue()
    private var watchdogTask: Task<Void, Never>?

    private var typewriterConfiguration: TypewriterConfiguration = .balanced
    private var performanceProfile: PerformanceProfile = .balanced
    private var fixedTimingOverride: ResolvedTiming?
    private var minimumTextAnimationWindow: TimeInterval = 0

    init() {
        currentTiming = ResolvedTiming(
            charsPerStep: 6,
            baseDuration: 0.012,
            elementGapDuration: 0.03,
            commaPause: 0.015,
            sentencePause: 0.045,
            jitterMax: 0.005
        )
    }

    func applyConfiguration(
        typewriter: TypewriterConfiguration,
        performanceProfile: PerformanceProfile
    ) {
        typewriterConfiguration = typewriter
        self.performanceProfile = performanceProfile
    }

    func enqueue(view: UIView) {
        taskQueue.decompose(
            view: view,
            isRoot: true,
            typewriterConfiguration: typewriterConfiguration,
            onLayoutChange: onLayoutChange
        )
        if !isRunning {
            runNext()
        }
    }

    func reset() {
        completeAll()
    }

    func resolvedTiming(forPendingTaskCount pendingTaskCount: Int) -> ResolvedTiming {
        RevealTimingResolver.resolveTiming(
            pendingTaskCount: pendingTaskCount,
            typewriterConfiguration: typewriterConfiguration,
            performanceProfile: performanceProfile,
            fixedTimingOverride: fixedTimingOverride
        )
    }

    func resolveTextTiming(_ timing: ResolvedTiming, totalCharacters: Int) -> ResolvedTiming {
        RevealTimingResolver.resolveTextTiming(
            timing,
            totalCharacters: totalCharacters,
            minimumTextAnimationWindow: minimumTextAnimationWindow
        )
    }

    func setFixedTiming(_ timing: ResolvedTiming?) {
        fixedTimingOverride = timing
    }

    func setMinimumTextAnimationWindow(_ duration: TimeInterval) {
        minimumTextAnimationWindow = max(0, duration)
    }
}

// MARK: - Task Execution

private extension RevealSequencer {
    func completeAll() {
        cancelWatchdog()
        RevealAnimator.completeTask(currentTask, cancelBlockReveal: cancelBlockRevealAnimation)
        for task in taskQueue.tasks {
            RevealAnimator.completeTask(task, cancelBlockReveal: cancelBlockRevealAnimation)
        }
        taskQueue.removeAll()
        isRunning = false
        currentTask = nil
        currentTaskToken = nil
    }

    func runNext() {
        guard !taskQueue.isEmpty else {
            isRunning = false
            onComplete?()
            return
        }

        isRunning = true
        let task = taskQueue.removeFirst()
        let token = UUID()
        currentTask = task
        currentTaskToken = token
        currentTiming = resolvedTiming(forPendingTaskCount: taskQueue.count)
        feedWatchdog()

        switch task {
        case let .block(view):
            if view is BlockRevealAnimating {
                startBlockRevealAnimation(for: view, token: token)
            } else {
                UIView.animate(withDuration: RevealAnimator.blockRevealDuration, animations: {
                    view.alpha = 1
                }) { [weak self] _ in
                    guard let self, self.currentTaskToken == token else { return }
                    self.onLayoutChange?(view)
                    self.finishCurrentTask(withGap: true)
                }
            }

        case let .label(label):
            UIView.animate(withDuration: 0.1, animations: {
                label.alpha = 1
            }) { [weak self] _ in
                guard let self, self.currentTaskToken == token else { return }
                self.finishCurrentTask(withGap: false)
            }

        case let .show(view):
            onLayoutChange?(nil)
            UIView.animate(withDuration: 0.15, animations: {
                view.alpha = 1
            }) { [weak self] _ in
                guard let self, self.currentTaskToken == token else { return }
                self.finishCurrentTask(withGap: true)
            }

        case let .text(textView):
            if textView.totalCharacterCount == 0 {
                finishCurrentTask(withGap: false)
            } else {
                let textTiming = resolveTextTiming(currentTiming, totalCharacters: textView.totalCharacterCount)
                typeNextBatch(textView: textView, from: 0, token: token, timing: textTiming)
            }
        }
    }

    func finishCurrentTask(withGap: Bool) {
        cancelWatchdog()
        currentTask = nil
        currentTaskToken = nil

        if withGap, currentTiming.elementGapDuration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + currentTiming.elementGapDuration) { [weak self] in
                self?.runNext()
            }
        } else {
            runNext()
        }
    }
}

// MARK: - Block Reveal

private extension RevealSequencer {
    func advanceBlockRevealAnimation() {
        guard let view = blockRevealView,
              let revealable = view as? BlockRevealAnimating,
              case let .block(currentView)? = currentTask,
              currentView === view
        else {
            cancelBlockRevealAnimation()
            return
        }

        let elapsed = Date.timeIntervalSinceReferenceDate - blockRevealStartTime
        let (easedProgress, isComplete) = RevealAnimator.advanceBlockRevealProgress(elapsed: elapsed)

        if revealable.setBlockRevealProgress(easedProgress) {
            onLayoutChange?(view)
        }

        guard isComplete else { return }

        cancelBlockRevealAnimation()
        onLayoutChange?(view)
        finishCurrentTask(withGap: true)
    }

    func cancelBlockRevealAnimation() {
        blockRevealTask?.cancel()
        blockRevealTask = nil
        blockRevealView = nil
        blockRevealStartTime = 0
    }

    func startBlockRevealAnimation(for view: UIView, token: UUID) {
        guard currentTaskToken == token else { return }

        cancelBlockRevealAnimation()
        blockRevealView = view
        blockRevealStartTime = Date.timeIntervalSinceReferenceDate

        UIView.animate(withDuration: RevealAnimator.blockRevealDuration) {
            view.alpha = 1
        }

        blockRevealTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                self.advanceBlockRevealAnimation()
                guard self.blockRevealView != nil else { return }
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }
}

// MARK: - Character Reveal

private extension RevealSequencer {
    static let watchdogTimeout: TimeInterval = 4.0

    func typeNextBatch(
        textView: TextFlowView,
        from currentIndex: Int,
        token: UUID,
        timing: ResolvedTiming
    ) {
        guard currentTaskToken == token else { return }
        feedWatchdog()

        let total = textView.totalCharacterCount
        guard currentIndex < total else {
            onLayoutChange?(textView)
            finishCurrentTask(withGap: false)
            return
        }

        let nextIndex = min(currentIndex + timing.charsPerStep, total)
        let heightChanged = textView.revealCharacters(upTo: nextIndex)

        if heightChanged {
            onLayoutChange?(textView)
        }

        let delay = RevealTimingResolver.calculateDelay(
            originalString: textView.originalAttributedString,
            from: currentIndex,
            to: nextIndex,
            timing: timing
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.typeNextBatch(textView: textView, from: nextIndex, token: token, timing: timing)
        }
    }
}

// MARK: - Watchdog

private extension RevealSequencer {
    func cancelWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    func feedWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.watchdogTimeout))

            guard !Task.isCancelled else { return }
            self?.handleWatchdogTimeout()
        }
    }

    func handleWatchdogTimeout() {
        guard isRunning else { return }
        RevealAnimator.completeTask(currentTask, cancelBlockReveal: cancelBlockRevealAnimation)
        finishCurrentTask(withGap: false)
    }
}
