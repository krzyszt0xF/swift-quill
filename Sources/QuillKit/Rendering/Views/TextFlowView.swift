import UIKit

final class TextFlowView: UIView {
    var lastRevealedIndex: Int { revealController.lastRevealedIndex }
    var originalAttributedString: NSAttributedString? { revealController.originalAttributedString }
    var onLinkTap: ((URL) -> Void)?

    var totalCharacterCount: Int { revealController.totalCharacterCount }

    private let textContentStorage = NSTextContentStorage()
    private let textContainer = NSTextContainer()
    private let textLayoutManager = NSTextLayoutManager()
    private var heightConstraint: NSLayoutConstraint?
    private var streamingRevealTask: Task<Void, Never>?
    private var deferredStreamingStartTask: Task<Void, Never>?
    private var revealFadeTasks: [UUID: Task<Void, Never>] = [:]

    private var renderer = TextFlowRenderer()
    private var revealController = TextFlowRevealController()
    private var layoutController = TextFlowLayoutController()
    private let linkInteraction = TextFlowLinkInteraction()

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: heightConstraint?.constant ?? 0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextContainer()

        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = true

        translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint?.priority = .required
        heightConstraint?.isActive = true

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        addGestureRecognizer(tapGestureRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        streamingRevealTask?.cancel()
        deferredStreamingStartTask?.cancel()
        for task in revealFadeTasks.values {
            task.cancel()
        }
        revealFadeTasks.removeAll()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        renderer.draw(textLayoutManager: textLayoutManager, in: context)

        if let attributedString = textContentStorage.attributedString {
            renderer.drawBlockquoteBars(
                attributedString: attributedString,
                textLayoutManager: textLayoutManager,
                textContentStorage: textContentStorage,
                in: context
            )
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }

    func configure(with attributedString: NSAttributedString) {
        resetStreamingState(clearTiming: true)
        revealController.setOriginalAttributedString(nil)
        revealController.workingAttributedString = nil
        revealController.setLastRevealedIndex(attributedString.length)
        revealController.previousStreamingTargetLength = attributedString.length
        textContentStorage.attributedString = attributedString
        setNeedsLayout()
        setNeedsDisplay()
    }

    func configureStreaming(
        with attributedString: NSAttributedString,
        charsPerStep: Int,
        baseDuration: TimeInterval,
        commaPause: TimeInterval,
        sentencePause: TimeInterval,
        jitterMax: TimeInterval = 0,
        startBufferCharacters: Int = 0,
        maxStartDelay: TimeInterval = 0,
        idleTimeout: TimeInterval = 0.30,
        revealInitialAlpha: CGFloat = 1,
        revealFadeDuration: TimeInterval = 0
    ) {
        guard revealController.shouldAnimateStreamingUpdate(
            with: attributedString,
            currentStorageAttributedString: textContentStorage.attributedString
        ) else {
            configure(with: attributedString)
            return
        }

        let visibleCharacterCount = revealController.currentVisibleCharacterCount(
            currentStorageLength: textContentStorage.attributedString?.length ?? 0
        )
        guard attributedString.length > visibleCharacterCount else {
            configure(with: attributedString)
            return
        }

        let now = Date.timeIntervalSinceReferenceDate
        revealController.updateStreamCadence(now: now)
        let resolvedCharsPerStep = max(1, charsPerStep)
        let resolvedBaseDuration = max(0.001, baseDuration)
        let resolvedCommaPause = max(0, commaPause)
        let resolvedJitterMax = max(0, jitterMax)
        let resolvedSentencePause = max(0, sentencePause)
        let resolvedStartBufferCharacters = max(0, startBufferCharacters)
        let resolvedMaxStartDelay = max(0, maxStartDelay)
        let resolvedIdleTimeout = max(0.05, idleTimeout)
        let resolvedRevealInitialAlpha = min(max(0, revealInitialAlpha), 1)
        let resolvedRevealFadeDuration = max(0, revealFadeDuration)
        revealController.previousStreamingTargetLength = attributedString.length
        revealController.streamingIdleTimeout = resolvedIdleTimeout
        revealController.revealFadeConfiguration = TextFlowRevealController.RevealFadeConfiguration(
            initialAlpha: resolvedRevealInitialAlpha,
            duration: resolvedRevealFadeDuration
        )

        revealController.streamingProfile = TextFlowRevealController.StreamingProfile(
            charsPerStep: resolvedCharsPerStep,
            baseDuration: resolvedBaseDuration,
            commaPause: resolvedCommaPause,
            jitterMax: resolvedJitterMax,
            sentencePause: resolvedSentencePause
        )

        cancelRevealFadeTasks()
        let workingString = revealController.installStreamingTarget(
            attributedString,
            visibleCharacterCount: visibleCharacterCount
        )
        textContentStorage.attributedString = workingString
        setNeedsLayout()
        setNeedsDisplay()

        let backlog = attributedString.length - visibleCharacterCount
        if shouldDeferStreamingStart(
            now: now,
            backlog: backlog,
            startBufferCharacters: resolvedStartBufferCharacters,
            maxStartDelay: resolvedMaxStartDelay
        ) {
            scheduleDeferredStreamingStart(
                now: now,
                maxStartDelay: resolvedMaxStartDelay
            )
            return
        }

        revealController.pendingStreamingStartTime = nil
        deferredStreamingStartTask?.cancel()
        deferredStreamingStartTask = nil
        startStreamingRevealIfNeeded()
    }

    func finishReveal() {
        resetStreamingState(clearTiming: true)

        if let restoredString = revealController.finishReveal(
            currentAttributedStringLength: textContentStorage.attributedString?.length ?? 0
        ) {
            textContentStorage.attributedString = restoredString
            setNeedsDisplay()
            return
        }
    }

    func prepareForReveal() {
        resetStreamingState(clearTiming: true)

        if let workingString = revealController.prepareForReveal(
            currentAttributedString: textContentStorage.attributedString
        ) {
            textContentStorage.attributedString = workingString
            setNeedsLayout()
            setNeedsDisplay()
        }
    }

    func configureRevealFade(initialAlpha: CGFloat, duration: TimeInterval) {
        revealController.revealFadeConfiguration = TextFlowRevealController.RevealFadeConfiguration(
            initialAlpha: min(max(0, initialAlpha), 1),
            duration: max(0, duration)
        )
    }

    @discardableResult
    func revealCharacters(upTo index: Int) -> Bool {
        let oldHeight = heightConstraint?.constant ?? 0

        guard let result = revealController.applyReveal(upTo: index) else { return false }

        textContentStorage.attributedString = revealController.workingAttributedString
        updateLayout()
        setNeedsDisplay()

        if revealController.revealFadeConfiguration.isEnabled {
            scheduleRevealFade(for: result.revealRange, generation: revealController.revealFadeGeneration)
        }

        let newHeight = heightConstraint?.constant ?? 0
        return abs(newHeight - oldHeight) > 0.5
    }

    func displayedForegroundColor(at index: Int) -> UIColor? {
        guard let attributedString = textContentStorage.attributedString,
              index >= 0,
              index < attributedString.length
        else {
            return nil
        }

        return attributedString.attribute(.foregroundColor, at: index, effectiveRange: nil) as? UIColor
    }

    func handleTap(at point: CGPoint) {
        guard let url = linkURL(at: point) else { return }
        onLinkTap?(url)
    }

    func linkURL(at point: CGPoint) -> URL? {
        let visibleCharacterCount = revealController.currentVisibleCharacterCount(
            currentStorageLength: textContentStorage.attributedString?.length ?? 0
        )
        return linkInteraction.linkURL(
            at: point,
            visibleCharacterCount: visibleCharacterCount,
            textLayoutManager: textLayoutManager,
            textContentStorage: textContentStorage,
            bounds: bounds,
            originalAttributedString: revealController.originalAttributedString,
            updateLayout: { [weak self] in self?.updateLayout() }
        )
    }
}

private extension TextFlowView {
    enum StreamingRevealStep {
        case done
        case reveal(index: Int, delay: TimeInterval)
        case sleep(TimeInterval)
    }

    @objc func handleTapGesture(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        handleTap(at: recognizer.location(in: self))
    }

    func resetStreamingState(clearTiming: Bool) {
        streamingRevealTask?.cancel()
        streamingRevealTask = nil
        deferredStreamingStartTask?.cancel()
        deferredStreamingStartTask = nil
        cancelRevealFadeTasks()
        revealController.resetStreamingState(clearTiming: clearTiming)
        layoutController.resetCache()
    }

    func cancelRevealFadeTasks() {
        for task in revealFadeTasks.values {
            task.cancel()
        }
        revealFadeTasks.removeAll()
    }

    func scheduleRevealFade(for revealRange: NSRange, generation: Int) {
        let midpointAlpha = revealController.midpointAlpha()
        let stepDelay = revealController.fadeStepDelay()
        let taskID = UUID()

        let task = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in
                    self?.revealFadeTasks[taskID] = nil
                }
            }

            if stepDelay > 0 {
                try? await Task.sleep(for: .seconds(stepDelay))
            }

            let appliedMidpoint = await MainActor.run { [weak self] in
                guard let self,
                      !Task.isCancelled,
                      self.revealController.revealFadeGeneration == generation else {
                    return false
                }

                self.revealController.applyAttributes(in: revealRange, alphaMultiplier: midpointAlpha)
                if let workingAttributedString = self.revealController.workingAttributedString {
                    self.textContentStorage.attributedString = workingAttributedString
                    self.setNeedsDisplay()
                }

                return true
            }
            guard appliedMidpoint else { return }

            if stepDelay > 0 {
                try? await Task.sleep(for: .seconds(stepDelay))
            }

            await MainActor.run { [weak self] in
                guard let self,
                      !Task.isCancelled,
                      self.revealController.revealFadeGeneration == generation else {
                    return
                }

                self.revealController.applyAttributes(in: revealRange, alphaMultiplier: nil)
                if let workingAttributedString = self.revealController.workingAttributedString {
                    self.textContentStorage.attributedString = workingAttributedString
                    self.setNeedsDisplay()
                }
            }
        }

        revealFadeTasks[taskID] = task
    }

    func shouldDeferStreamingStart(
        now: TimeInterval,
        backlog: Int,
        startBufferCharacters: Int,
        maxStartDelay: TimeInterval
    ) -> Bool {
        guard startBufferCharacters > 0,
              maxStartDelay > 0,
              backlog < startBufferCharacters
        else {
            revealController.pendingStreamingStartTime = nil
            return false
        }

        if revealController.pendingStreamingStartTime == nil {
            revealController.pendingStreamingStartTime = now
        }

        guard let pendingStartTime = revealController.pendingStreamingStartTime else {
            return false
        }

        return (now - pendingStartTime) < maxStartDelay
    }

    func scheduleDeferredStreamingStart(now: TimeInterval, maxStartDelay: TimeInterval) {
        guard maxStartDelay > 0 else {
            revealController.pendingStreamingStartTime = nil
            startStreamingRevealIfNeeded()
            return
        }

        let elapsed = revealController.pendingStreamingStartTime.map { max(0, now - $0) } ?? 0
        let remaining = max(0.001, maxStartDelay - elapsed)

        deferredStreamingStartTask?.cancel()
        deferredStreamingStartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))

            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }

                self.revealController.pendingStreamingStartTime = nil
                self.deferredStreamingStartTask = nil
                self.startStreamingRevealIfNeeded()
            }
        }
    }

    func startStreamingRevealIfNeeded() {
        guard streamingRevealTask == nil,
              revealController.streamingProfile != nil
        else {
            return
        }

        streamingRevealTask = Task { [weak self] in
            streamingLoop: while !Task.isCancelled {
                let step = await MainActor.run { [weak self] in
                    self?.makeStreamingRevealStep() ?? .done
                }

                switch step {
                case .done:
                    break streamingLoop
                case let .reveal(index, delay):
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { break streamingLoop }

                    await MainActor.run { [weak self] in
                        self?.revealCharacters(upTo: index)
                    }
                case let .sleep(delay):
                    try? await Task.sleep(for: .seconds(delay))
                }
            }

            await MainActor.run { [weak self] in
                self?.streamingRevealTask = nil
            }
        }
    }

    func makeStreamingRevealStep() -> StreamingRevealStep {
        guard let profile = revealController.streamingProfile,
              let originalAttributedString = revealController.originalAttributedString
        else {
            return .done
        }

        let totalCharacters = originalAttributedString.length
        if revealController.lastRevealedIndex >= totalCharacters {
            let now = Date.timeIntervalSinceReferenceDate
            let idleSinceLastUpdate = now - (revealController.lastStreamingUpdateTime ?? now)
            if idleSinceLastUpdate >= revealController.streamingIdleTimeout {
                revealController.setOriginalAttributedString(nil)
                revealController.workingAttributedString = nil
                revealController.streamingProfile = nil
                return .done
            }

            return .sleep(0.016)
        }

        let nextIndex = min(revealController.lastRevealedIndex + profile.charsPerStep, totalCharacters)
        let delayDuration = revealController.streamingDelay(
            in: originalAttributedString.string as NSString,
            from: revealController.lastRevealedIndex,
            to: nextIndex,
            baseDuration: profile.baseDuration,
            commaPause: profile.commaPause,
            jitterMax: profile.jitterMax,
            sentencePause: profile.sentencePause
        )

        return .reveal(index: nextIndex, delay: delayDuration)
    }

    func setupTextContainer() {
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.size = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textLayoutManager.textContainer = textContainer
        textContentStorage.addTextLayoutManager(textLayoutManager)
    }

    func updateLayout() {
        textContainer.size = CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)

        let height = layoutController.computeHeight(
            textLayoutManager: textLayoutManager,
            textContentStorage: textContentStorage,
            originalAttributedString: revealController.originalAttributedString,
            lastRevealedIndex: revealController.lastRevealedIndex,
            boundsWidth: bounds.width
        )

        heightConstraint?.constant = ceil(height)
        invalidateIntrinsicContentSize()
    }
}
