import UIKit

/// Orchestrates sequential reveal animation for streamed markdown views.
@MainActor
public final class RevealSequencer {
    public struct ResolvedTiming: Equatable, Sendable {
        public var charsPerStep: Int
        public var baseDuration: TimeInterval
        public var elementGapDuration: TimeInterval
        public var commaPause: TimeInterval
        public var sentencePause: TimeInterval
        public var jitterMax: TimeInterval

        public init(
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

    public var onComplete: (() -> Void)?
    public var onLayoutChange: (() -> Void)?
    private var isRunning = false

    private var currentTask: AnimationTask?
    private var currentTaskToken: UUID?
    private var currentTiming: ResolvedTiming
    private var taskQueue: [AnimationTask] = []
    private var watchdogTask: Task<Void, Never>?

    private var typewriterConfiguration: TypewriterConfiguration = .balanced
    private var performanceProfile: PerformanceProfile = .balanced
    private var fixedTimingOverride: ResolvedTiming?
    private var minimumTextAnimationWindow: TimeInterval = 0

    public init() {
        currentTiming = ResolvedTiming(
            charsPerStep: 6,
            baseDuration: 0.012,
            elementGapDuration: 0.03,
            commaPause: 0.015,
            sentencePause: 0.045,
            jitterMax: 0.005
        )
    }

    public func enqueue(view: UIView) {
        decompose(view: view, isRoot: true)
        if !isRunning {
            runNext()
        }
    }

    public func reset() {
        completeAll()
    }

    public func applyConfiguration(
        typewriter: TypewriterConfiguration,
        performanceProfile: PerformanceProfile
    ) {
        typewriterConfiguration = typewriter
        self.performanceProfile = performanceProfile
    }

    public func setFixedTiming(_ timing: ResolvedTiming?) {
        fixedTimingOverride = timing
    }

    public func setMinimumTextAnimationWindow(_ duration: TimeInterval) {
        minimumTextAnimationWindow = max(0, duration)
    }

    func resolvedTiming(forPendingTaskCount pendingTaskCount: Int) -> ResolvedTiming {
        if let fixedTimingOverride {
            return fixedTimingOverride
        }

        let profileTiming: TypewriterConfiguration.QueueTiming
        if pendingTaskCount >= typewriterConfiguration.highQueueLowerBound {
            profileTiming = typewriterConfiguration.highQueue
        } else if pendingTaskCount >= typewriterConfiguration.mediumQueueLowerBound {
            profileTiming = typewriterConfiguration.mediumQueue
        } else {
            profileTiming = typewriterConfiguration.lowQueue
        }

        let multiplier: Double
        switch performanceProfile {
        case .snappy:
            multiplier = 0.9
        case .balanced:
            multiplier = 1.0
        case .longForm:
            multiplier = 1.1
        }

        return ResolvedTiming(
            charsPerStep: profileTiming.charsPerStep,
            baseDuration: profileTiming.baseDuration * multiplier,
            elementGapDuration: profileTiming.elementGapDuration * multiplier,
            commaPause: typewriterConfiguration.commaPause,
            sentencePause: typewriterConfiguration.sentencePause,
            jitterMax: typewriterConfiguration.jitterMax
        )
    }

    func resolveTextTiming(_ timing: ResolvedTiming, totalCharacters: Int) -> ResolvedTiming {
        guard minimumTextAnimationWindow > 0, totalCharacters > 0 else {
            return timing
        }

        let requiredSteps = max(1, Int(ceil(minimumTextAnimationWindow / timing.baseDuration)))
        let reducedCharsPerStep = max(1, Int(floor(Double(totalCharacters) / Double(requiredSteps))))
        let effectiveCharsPerStep = min(timing.charsPerStep, reducedCharsPerStep)
        let effectiveStepCount = max(1, Int(ceil(Double(totalCharacters) / Double(effectiveCharsPerStep))))
        let minimumBaseDuration = minimumTextAnimationWindow / Double(effectiveStepCount)
        let effectiveBaseDuration = max(timing.baseDuration, minimumBaseDuration)

        return ResolvedTiming(
            charsPerStep: effectiveCharsPerStep,
            baseDuration: effectiveBaseDuration,
            elementGapDuration: timing.elementGapDuration,
            commaPause: timing.commaPause,
            sentencePause: timing.sentencePause,
            jitterMax: timing.jitterMax
        )
    }
}

// MARK: - View Decomposition

private extension RevealSequencer {
    enum AnimationTask {
        case block(UIView)
        case label(UILabel)
        case show(UIView)
        case text(TextFlowView)
    }

    func decompose(view: UIView, isRoot: Bool) {
        if let textFlow = view as? TextFlowView {
            if isRoot {
                textFlow.alpha = 0
                taskQueue.append(.show(textFlow))
            }
            textFlow.prepareForReveal()
            taskQueue.append(.text(textFlow))
            return
        }

        if let label = view as? UILabel {
            label.alpha = 0
            taskQueue.append(.label(label))
            return
        }

        if view is CodeBlockView || view is PlaceholderBlockView {
            view.alpha = 0
            taskQueue.append(.block(view))
            return
        }

        if view is UIButton || view is UIImageView {
            view.alpha = 0
            taskQueue.append(.block(view))
            return
        }

        if let stack = view as? UIStackView {
            if isRoot {
                view.alpha = 0
                taskQueue.append(.show(view))
            }
            for sub in stack.arrangedSubviews {
                decompose(view: sub, isRoot: false)
            }
            return
        }

        if !view.subviews.isEmpty {
            if isRoot {
                view.alpha = 0
                taskQueue.append(.show(view))
            }
            for sub in view.subviews {
                decompose(view: sub, isRoot: false)
            }
            return
        }

        view.alpha = 0
        taskQueue.append(.block(view))
    }
}

// MARK: - Task Execution

private extension RevealSequencer {
    func completeAll() {
        cancelWatchdog()
        completeTask(currentTask)
        for task in taskQueue {
            completeTask(task)
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
            UIView.animate(withDuration: 0.2, animations: {
                view.alpha = 1
            }) { [weak self] _ in
                guard let self, self.currentTaskToken == token else { return }
                self.onLayoutChange?()
                self.finishCurrentTask(withGap: true)
            }

        case let .label(label):
            UIView.animate(withDuration: 0.1, animations: {
                label.alpha = 1
            }) { [weak self] _ in
                guard let self, self.currentTaskToken == token else { return }
                self.finishCurrentTask(withGap: false)
            }

        case let .show(view):
            onLayoutChange?()
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

    func completeTask(_ task: AnimationTask?) {
        switch task {
        case let .block(view):
            view.alpha = 1
        case let .label(label):
            label.alpha = 1
        case let .show(view):
            view.alpha = 1
        case let .text(textView):
            textView.finishReveal()
        case .none:
            break
        }
    }
}

// MARK: - Character Reveal

private extension RevealSequencer {
    static let commaChars: Set<unichar> = [0x002C, 0xFF0C, 0x3001]
    static let sentenceEnders: Set<unichar> = [0x002E, 0x0021, 0x003F, 0x000A]
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
            onLayoutChange?()
            finishCurrentTask(withGap: false)
            return
        }

        let nextIndex = min(currentIndex + timing.charsPerStep, total)
        textView.revealCharacters(upTo: nextIndex)

        onLayoutChange?()

        let delay = calculateDelay(textView: textView, from: currentIndex, to: nextIndex, timing: timing)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.typeNextBatch(textView: textView, from: nextIndex, token: token, timing: timing)
        }
    }

    func calculateDelay(
        textView: TextFlowView,
        from startIndex: Int,
        to endIndex: Int,
        timing: ResolvedTiming
    ) -> TimeInterval {
        var extraDelay: TimeInterval = 0

        if let original = textView.originalAttributedString {
            let nsString = original.string as NSString
            for i in startIndex..<endIndex where i < nsString.length {
                let char = nsString.character(at: i)
                if Self.sentenceEnders.contains(char) {
                    extraDelay = max(extraDelay, timing.sentencePause)
                } else if Self.commaChars.contains(char) {
                    extraDelay = max(extraDelay, timing.commaPause)
                }
            }
        }

        let jitter = timing.jitterMax > 0 ? Double.random(in: 0...timing.jitterMax) : 0
        return timing.baseDuration + extraDelay + jitter
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
        completeTask(currentTask)
        finishCurrentTask(withGap: false)
    }
}
