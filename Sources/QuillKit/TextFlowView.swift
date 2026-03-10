import UIKit

final class TextFlowView: UIView {
    private struct StreamingProfile {
        var charsPerStep: Int
        var baseDuration: TimeInterval
        var commaPause: TimeInterval
        var sentencePause: TimeInterval
    }

    private(set) var lastRevealedIndex = 0
    private(set) var originalAttributedString: NSAttributedString?

    var totalCharacterCount: Int { originalAttributedString?.length ?? 0 }

    private let textContentStorage = NSTextContentStorage()
    private let textContainer = NSTextContainer()
    private let textLayoutManager = NSTextLayoutManager()
    private var heightConstraint: NSLayoutConstraint?
    private var workingAttributedString: NSMutableAttributedString?
    private var streamingRevealTask: Task<Void, Never>?
    private var deferredStreamingStartTask: Task<Void, Never>?
    private var streamingProfile: StreamingProfile?
    private var pendingStreamingStartTime: TimeInterval?
    private var lastStreamingUpdateTime: TimeInterval?
    private var averagedStreamInterval: TimeInterval?
    private var previousStreamingTargetLength = 0

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: heightConstraint?.constant ?? 0)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTextContainer()

        backgroundColor = .clear
        isOpaque = false

        translatesAutoresizingMaskIntoConstraints = false
        heightConstraint = heightAnchor.constraint(equalToConstant: 0)
        heightConstraint?.priority = .required
        heightConstraint?.isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        streamingRevealTask?.cancel()
        deferredStreamingStartTask?.cancel()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        textLayoutManager.enumerateTextLayoutFragments(
            from: textLayoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            fragment.draw(at: fragment.layoutFragmentFrame.origin, in: context)
            return true
        }

        drawBlockquoteBars(in: context)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }

    func configure(with attributedString: NSAttributedString) {
        resetStreamingState(clearTiming: true)
        originalAttributedString = nil
        workingAttributedString = nil
        lastRevealedIndex = attributedString.length
        previousStreamingTargetLength = attributedString.length
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
        startBufferCharacters: Int = 0,
        maxStartDelay: TimeInterval = 0
    ) {
        guard shouldAnimateStreamingUpdate(with: attributedString) else {
            configure(with: attributedString)
            return
        }

        let visibleCharacterCount = currentVisibleCharacterCount()
        guard attributedString.length > visibleCharacterCount else {
            configure(with: attributedString)
            return
        }

        let now = Date.timeIntervalSinceReferenceDate
        updateStreamCadence(now: now)
        let resolvedCharsPerStep = max(1, charsPerStep)
        let resolvedBaseDuration = max(0.001, baseDuration)
        let resolvedCommaPause = max(0, commaPause)
        let resolvedSentencePause = max(0, sentencePause)
        let resolvedStartBufferCharacters = max(0, startBufferCharacters)
        let resolvedMaxStartDelay = max(0, maxStartDelay)
        let previousTargetLength = max(previousStreamingTargetLength, visibleCharacterCount)
        let appendedCharacters = max(1, attributedString.length - previousTargetLength)
        previousStreamingTargetLength = attributedString.length

        streamingProfile = StreamingProfile(
            charsPerStep: resolvedCharsPerStep,
            baseDuration: resolveAdaptiveBaseDuration(
                baseDuration: resolvedBaseDuration,
                appendedCharacters: appendedCharacters
            ),
            commaPause: resolvedCommaPause,
            sentencePause: resolvedSentencePause
        )

        installStreamingTarget(attributedString, visibleCharacterCount: visibleCharacterCount)

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

        pendingStreamingStartTime = nil
        deferredStreamingStartTask?.cancel()
        deferredStreamingStartTask = nil
        startStreamingRevealIfNeeded()
    }

    func finishReveal() {
        resetStreamingState(clearTiming: true)

        if let originalAttributedString {
            textContentStorage.attributedString = originalAttributedString
            lastRevealedIndex = originalAttributedString.length
            self.originalAttributedString = nil
            workingAttributedString = nil
            previousStreamingTargetLength = lastRevealedIndex
            setNeedsDisplay()
            return
        }

        lastRevealedIndex = textContentStorage.attributedString?.length ?? 0
        previousStreamingTargetLength = lastRevealedIndex
    }

    func prepareForReveal() {
        resetStreamingState(clearTiming: true)

        guard originalAttributedString == nil,
              let attributedString = textContentStorage.attributedString,
              attributedString.length > 0 else { return }

        originalAttributedString = NSAttributedString(attributedString: attributedString)

        let workingString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: workingString.length)
        workingString.addAttribute(.foregroundColor, value: UIColor.clear, range: fullRange)
        workingString.removeAttribute(.link, range: fullRange)

        workingAttributedString = workingString
        textContentStorage.attributedString = workingString
        textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
        lastRevealedIndex = 0
    }

    func revealCharacters(upTo index: Int) {
        guard let originalAttributedString,
              let workingAttributedString,
              index > lastRevealedIndex,
              index <= originalAttributedString.length else { return }

        let revealRange = NSRange(location: lastRevealedIndex, length: index - lastRevealedIndex)
        originalAttributedString.enumerateAttributes(in: revealRange) { attributes, range, _ in
            workingAttributedString.setAttributes(attributes, range: range)
        }

        textContentStorage.attributedString = workingAttributedString
        lastRevealedIndex = index
        setNeedsDisplay()
    }
}

private extension TextFlowView {
    static let commaCharacters: Set<unichar> = [0x002C, 0xFF0C, 0x3001]
    static let sentenceCharacters: Set<unichar> = [0x002E, 0x0021, 0x003F, 0x000A]
    static let streamIntervalSmoothingFactor = 0.35
    static let minimumAnimationWindow: TimeInterval = 0.14
    static let maximumAnimationWindow: TimeInterval = 0.45
    static let maximumAdaptiveBaseDuration: TimeInterval = 0.080
    static let idleRevealPollInterval: TimeInterval = 0.016
    static let idleRevealTimeout: TimeInterval = 0.30

    func resetStreamingState(clearTiming: Bool) {
        streamingRevealTask?.cancel()
        streamingRevealTask = nil
        deferredStreamingStartTask?.cancel()
        deferredStreamingStartTask = nil
        streamingProfile = nil
        pendingStreamingStartTime = nil

        if clearTiming {
            lastStreamingUpdateTime = nil
            averagedStreamInterval = nil
            previousStreamingTargetLength = 0
        }
    }

    func updateStreamCadence(now: TimeInterval) {
        if let lastStreamingUpdateTime {
            let interval = max(0.001, now - lastStreamingUpdateTime)
            if let averagedStreamInterval {
                self.averagedStreamInterval = averagedStreamInterval + (interval - averagedStreamInterval) * Self.streamIntervalSmoothingFactor
            } else {
                averagedStreamInterval = interval
            }
        }

        lastStreamingUpdateTime = now
    }

    func resolveAdaptiveBaseDuration(
        baseDuration: TimeInterval,
        appendedCharacters: Int
    ) -> TimeInterval {
        guard let averagedStreamInterval else { return baseDuration }

        let targetWindow = min(
            max(averagedStreamInterval * 0.9, Self.minimumAnimationWindow),
            Self.maximumAnimationWindow
        )
        let perCharacter = targetWindow / Double(max(1, appendedCharacters))
        let clamped = min(perCharacter, Self.maximumAdaptiveBaseDuration)
        return max(baseDuration, clamped)
    }

    func installStreamingTarget(_ attributedString: NSAttributedString, visibleCharacterCount: Int) {
        let clampedVisibleCount = min(max(0, visibleCharacterCount), attributedString.length)
        let workingString = NSMutableAttributedString(attributedString: attributedString)
        hideCharacters(
            in: NSRange(location: clampedVisibleCount, length: attributedString.length - clampedVisibleCount),
            within: workingString
        )

        originalAttributedString = NSAttributedString(attributedString: attributedString)
        workingAttributedString = workingString
        lastRevealedIndex = clampedVisibleCount
        textContentStorage.attributedString = workingString
        setNeedsLayout()
        setNeedsDisplay()
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
            pendingStreamingStartTime = nil
            return false
        }

        if pendingStreamingStartTime == nil {
            pendingStreamingStartTime = now
        }

        guard let pendingStreamingStartTime else {
            return false
        }

        return (now - pendingStreamingStartTime) < maxStartDelay
    }

    func scheduleDeferredStreamingStart(now: TimeInterval, maxStartDelay: TimeInterval) {
        guard maxStartDelay > 0 else {
            pendingStreamingStartTime = nil
            startStreamingRevealIfNeeded()
            return
        }

        let elapsed = pendingStreamingStartTime.map { max(0, now - $0) } ?? 0
        let remaining = max(0.001, maxStartDelay - elapsed)

        deferredStreamingStartTask?.cancel()
        deferredStreamingStartTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard let self, !Task.isCancelled else { return }

            self.pendingStreamingStartTime = nil
            self.deferredStreamingStartTask = nil
            self.startStreamingRevealIfNeeded()
        }
    }

    func startStreamingRevealIfNeeded() {
        guard streamingRevealTask == nil,
              streamingProfile != nil
        else {
            return
        }

        streamingRevealTask = Task { @MainActor [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                guard let profile = self.streamingProfile,
                      let originalAttributedString = self.originalAttributedString
                else {
                    break
                }

                let totalCharacters = originalAttributedString.length
                if self.lastRevealedIndex >= totalCharacters {
                    let now = Date.timeIntervalSinceReferenceDate
                    let idleSinceLastUpdate = now - (self.lastStreamingUpdateTime ?? now)
                    if idleSinceLastUpdate >= Self.idleRevealTimeout {
                        self.originalAttributedString = nil
                        self.workingAttributedString = nil
                        self.streamingProfile = nil
                        self.streamingRevealTask = nil
                        return
                    }

                    try? await Task.sleep(for: .seconds(Self.idleRevealPollInterval))
                    continue
                }

                let nextIndex = min(self.lastRevealedIndex + profile.charsPerStep, totalCharacters)
                let delayDuration = self.streamingDelay(
                    in: originalAttributedString.string as NSString,
                    from: self.lastRevealedIndex,
                    to: nextIndex,
                    baseDuration: profile.baseDuration,
                    commaPause: profile.commaPause,
                    sentencePause: profile.sentencePause
                )

                try? await Task.sleep(for: .seconds(delayDuration))
                guard !Task.isCancelled else { return }
                self.revealCharacters(upTo: nextIndex)
            }

            self.streamingRevealTask = nil
        }
    }

    func currentVisibleCharacterCount() -> Int {
        if let originalAttributedString,
           let workingAttributedString,
           originalAttributedString.length == workingAttributedString.length {
            return lastRevealedIndex
        }

        return textContentStorage.attributedString?.length ?? 0
    }

    func currentVisiblePrefix() -> NSAttributedString {
        let visibleCharacterCount = currentVisibleCharacterCount()

        if let originalAttributedString,
           visibleCharacterCount <= originalAttributedString.length {
            return originalAttributedString.attributedSubstring(
                from: NSRange(location: 0, length: visibleCharacterCount)
            )
        }

        guard let currentAttributedString = textContentStorage.attributedString else {
            return NSAttributedString(string: "")
        }

        return currentAttributedString.attributedSubstring(
            from: NSRange(location: 0, length: min(visibleCharacterCount, currentAttributedString.length))
        )
    }

    func drawBlockquoteBars(in context: CGContext) {
        guard let attributedString = textContentStorage.attributedString else {
            return
        }

        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttribute(.blockquoteDepth, in: fullRange) { value, range, _ in
            guard let depth = value as? Int, depth > 0 else {
                return
            }

            let yExtents = yRange(for: range)
            guard yExtents.max > yExtents.min else {
                return
            }

            let xOrigin = CGFloat(depth - 1) * 16
            let barRect = CGRect(x: xOrigin, y: yExtents.min, width: 3, height: yExtents.max - yExtents.min)
            context.setFillColor(UIColor.systemGray3.cgColor)
            context.fill(barRect)
        }
    }

    func hideCharacters(in range: NSRange, within workingAttributedString: NSMutableAttributedString) {
        guard range.length > 0 else { return }

        workingAttributedString.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
        workingAttributedString.removeAttribute(.link, range: range)
    }

    func setupTextContainer() {
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.size = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textLayoutManager.textContainer = textContainer
        textContentStorage.addTextLayoutManager(textLayoutManager)
    }

    func shouldAnimateStreamingUpdate(with attributedString: NSAttributedString) -> Bool {
        let visiblePrefix = currentVisiblePrefix()
        guard visiblePrefix.length <= attributedString.length else {
            return false
        }

        let nextPrefix = attributedString.attributedSubstring(
            from: NSRange(location: 0, length: visiblePrefix.length)
        )
        return visiblePrefix.isEqual(to: nextPrefix)
    }

    func streamingDelay(
        in sourceString: NSString,
        from startIndex: Int,
        to endIndex: Int,
        baseDuration: TimeInterval,
        commaPause: TimeInterval,
        sentencePause: TimeInterval
    ) -> TimeInterval {
        let lowerBound = max(0, startIndex)
        let upperBound = max(lowerBound, min(endIndex, sourceString.length))
        var extraDuration: TimeInterval = 0

        if lowerBound < upperBound {
            for index in lowerBound..<upperBound {
                let scalar = sourceString.character(at: index)
                if Self.sentenceCharacters.contains(scalar) {
                    extraDuration = max(extraDuration, sentencePause)
                } else if Self.commaCharacters.contains(scalar) {
                    extraDuration = max(extraDuration, commaPause)
                }
            }
        }

        return baseDuration + extraDuration
    }

    func updateLayout() {
        textContainer.size = CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)

        var maxY: CGFloat = 0
        textLayoutManager.enumerateTextLayoutFragments(
            from: textLayoutManager.documentRange.location,
            options: [.ensuresLayout]
        ) { fragment in
            let fragmentMaxY = fragment.layoutFragmentFrame.maxY
            if fragmentMaxY > maxY {
                maxY = fragmentMaxY
            }
            return true
        }

        if maxY == 0,
           let attributedString = textContentStorage.attributedString,
           attributedString.length > 0 {
            let boundingSize = CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
            maxY = attributedString.boundingRect(
                with: boundingSize,
                options: [.usesLineFragmentOrigin],
                context: nil
            ).height
        }

        heightConstraint?.constant = ceil(maxY)
        invalidateIntrinsicContentSize()
    }

    func yRange(for characterRange: NSRange) -> (min: CGFloat, max: CGFloat) {
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = 0

        guard let startLocation = textLayoutManager.location(
            textLayoutManager.documentRange.location,
            offsetBy: characterRange.location
        ) else { return (0, 0) }

        guard let endLocation = textLayoutManager.location(
            startLocation,
            offsetBy: characterRange.length
        ) else { return (0, 0) }

        let textRange = NSTextRange(location: startLocation, end: endLocation)

        textLayoutManager.enumerateTextLayoutFragments(
            from: textRange?.location,
            options: [.ensuresLayout]
        ) { fragment in
            let location = fragment.rangeInElement.location
            guard let textRange,
                  location.compare(textRange.endLocation) != .orderedDescending
            else {
                return false
            }

            let frame = fragment.layoutFragmentFrame
            if frame.minY < minY {
                minY = frame.minY
            }
            if frame.maxY > maxY {
                maxY = frame.maxY
            }

            return true
        }

        return (minY == .greatestFiniteMagnitude ? 0 : minY, maxY)
    }
}
