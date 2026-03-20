import UIKit

@MainActor
final class RevealSequencer {
    var onComplete: (() -> Void)?
    var onLayoutChange: ((UIView?) -> Void)?
    private var isRunning = false

    private var blockRevealTask: Task<Void, Never>?
    private weak var blockRevealView: UIView?
    private var blockRevealStartTime: TimeInterval = 0
    private var currentTask: RevealTaskQueue.AnimationTask?
    private var currentTaskToken: UUID?
    private var currentTiming: RevealTiming
    private let generateID: () -> UUID
    private let now: () -> TimeInterval
    private let scheduleAfter: (_ delay: TimeInterval, _ operation: @escaping @MainActor () -> Void) -> Void
    private let sleep: (Duration) async -> Void
    private var taskQueue = RevealTaskQueue()
    private var watchdogTask: Task<Void, Never>?

    private var typewriterConfiguration: TypewriterConfiguration = .balanced
    private var performanceProfile: PerformanceProfile = .balanced
    private var fixedTimingOverride: RevealTiming?
    private var minimumTextAnimationWindow: TimeInterval = 0
    
    init(
        generateID: @escaping () -> UUID,
        now: @escaping () -> TimeInterval,
        scheduleAfter: @escaping (_ delay: TimeInterval, _ operation: @escaping @MainActor () -> Void) -> Void,
        sleep: @escaping (Duration) async -> Void) {
            self.generateID = generateID
            self.now = now
            self.scheduleAfter = scheduleAfter
            self.sleep = sleep
            currentTiming = .live
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

    func setFixedTiming(_ timing: RevealTiming?) {
        fixedTimingOverride = timing
    }

    func setMinimumTextAnimationWindow(_ duration: TimeInterval) {
        minimumTextAnimationWindow = max(0, duration)
    }
}

extension RevealSequencer {
    static var live: RevealSequencer {
        RevealSequencer(
            generateID: UUID.init,
            now: { Date.timeIntervalSinceReferenceDate },
            scheduleAfter: { delay, operation in
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    
                    operation()
                }
            },
            sleep: { duration in
                try? await Task.sleep(for: duration)
            }
        )
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
        let token = generateID()
        currentTask = task
        currentTaskToken = token
        currentTiming = fixedTimingOverride ?? RevealTiming(
            pendingTaskCount: taskQueue.count,
            typewriterConfiguration: typewriterConfiguration,
            performanceProfile: performanceProfile)
        feedWatchdog()

        switch task {
        case let .block(view):
            if view is BlockRevealAnimating {
                startBlockRevealAnimation(for: view, token: token)
            } else {
                UIView.animate(withDuration: RevealAnimator.blockRevealDuration, animations: {
                    view.alpha = 1
                }) { [weak self] _ in
                    guard
                        let self,
                        self.currentTaskToken == token
                    else { return }
                    
                    self.onLayoutChange?(view)
                    self.finishCurrentTask(withGap: true)
                }
            }

        case let .label(label):
            UIView.animate(withDuration: 0.1, animations: {
                label.alpha = 1
            }) { [weak self] _ in
                guard
                    let self,
                    self.currentTaskToken == token
                else { return }
                
                self.finishCurrentTask(withGap: false)
            }

        case let .show(view):
            onLayoutChange?(nil)
            UIView.animate(withDuration: 0.15, animations: {
                view.alpha = 1
            }) { [weak self] _ in
                guard
                    let self,
                    self.currentTaskToken == token
                else { return }
                
                self.finishCurrentTask(withGap: true)
            }

        case let .text(textView):
            if textView.totalCharacterCount == 0 {
                finishCurrentTask(withGap: false)
            } else {
                let textTiming = currentTiming.next(
                    totalCharacters: textView.totalCharacterCount,
                    minimumTextAnimationWindow: minimumTextAnimationWindow)
                typeNextBatch(textView: textView, from: 0, token: token, timing: textTiming)
            }
        }
    }

    func finishCurrentTask(withGap: Bool) {
        cancelWatchdog()
        currentTask = nil
        currentTaskToken = nil

        if withGap, currentTiming.elementGapDuration > 0 {
            scheduleAfter(currentTiming.elementGapDuration) { [weak self] in
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

        let elapsed = now() - blockRevealStartTime
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
        blockRevealStartTime = now()

        UIView.animate(withDuration: RevealAnimator.blockRevealDuration) {
            view.alpha = 1
        }

        blockRevealTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                self.advanceBlockRevealAnimation()
                guard self.blockRevealView != nil else { return }
                await self.sleep(.milliseconds(16))
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
        timing: RevealTiming
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

        let delay = timing.delay(
            from: currentIndex,
            to: nextIndex,
            originalString: textView.originalAttributedString)
        scheduleAfter(delay) { [weak self] in
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
            guard let self else { return }
            
            await self.sleep(.seconds(Self.watchdogTimeout))
            guard !Task.isCancelled else { return }
            
            self.handleWatchdogTimeout()
        }
    }

    func handleWatchdogTimeout() {
        guard isRunning else { return }
        
        RevealAnimator.completeTask(currentTask, cancelBlockReveal: cancelBlockRevealAnimation)
        finishCurrentTask(withGap: false)
    }
}
