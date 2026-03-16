import UIKit

final class TextFlowView: UIView {
    private struct StreamingProfile {
        var charsPerStep: Int
        var baseDuration: TimeInterval
        var commaPause: TimeInterval
        var jitterMax: TimeInterval
        var sentencePause: TimeInterval
    }

    private struct RevealFadeConfiguration {
        var initialAlpha: CGFloat = 0.2
        var duration: TimeInterval = 0.08

        var isEnabled: Bool {
            initialAlpha < 1 && duration > 0
        }
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
    private var previousStreamingTargetLength = 0
    private var streamingIdleTimeout: TimeInterval = 0.30
    private var revealFadeConfiguration = RevealFadeConfiguration()
    private var revealFadeTasks: [UUID: Task<Void, Never>] = [:]
    private var revealFadeGeneration = 0
    private var cachedPrefixHeight: CGFloat = 0
    private var cachedPrefixHeightKey: (revealIndex: Int, width: CGFloat) = (-1, 0)

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
        for task in revealFadeTasks.values {
            task.cancel()
        }
        revealFadeTasks.removeAll()
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
        jitterMax: TimeInterval = 0,
        startBufferCharacters: Int = 0,
        maxStartDelay: TimeInterval = 0,
        idleTimeout: TimeInterval = 0.30,
        revealInitialAlpha: CGFloat = 1,
        revealFadeDuration: TimeInterval = 0
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
        let resolvedJitterMax = max(0, jitterMax)
        let resolvedSentencePause = max(0, sentencePause)
        let resolvedStartBufferCharacters = max(0, startBufferCharacters)
        let resolvedMaxStartDelay = max(0, maxStartDelay)
        let resolvedIdleTimeout = max(0.05, idleTimeout)
        let resolvedRevealInitialAlpha = min(max(0, revealInitialAlpha), 1)
        let resolvedRevealFadeDuration = max(0, revealFadeDuration)
        previousStreamingTargetLength = attributedString.length
        streamingIdleTimeout = resolvedIdleTimeout
        revealFadeConfiguration = RevealFadeConfiguration(
            initialAlpha: resolvedRevealInitialAlpha,
            duration: resolvedRevealFadeDuration
        )

        streamingProfile = StreamingProfile(
            charsPerStep: resolvedCharsPerStep,
            baseDuration: resolvedBaseDuration,
            commaPause: resolvedCommaPause,
            jitterMax: resolvedJitterMax,
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
        lastRevealedIndex = revealImmediateStructuralMarkers(
            in: workingString,
            from: attributedString,
            startingAt: 0
        )
        setNeedsLayout()
        setNeedsDisplay()
    }

    func configureRevealFade(initialAlpha: CGFloat, duration: TimeInterval) {
        revealFadeConfiguration = RevealFadeConfiguration(
            initialAlpha: min(max(0, initialAlpha), 1),
            duration: max(0, duration)
        )
    }

    @discardableResult
    func revealCharacters(upTo index: Int) -> Bool {
        guard let originalAttributedString,
              let workingAttributedString,
              index > lastRevealedIndex,
              index <= originalAttributedString.length else { return false }

        let oldHeight = heightConstraint?.constant ?? 0

        let revealRange = NSRange(location: lastRevealedIndex, length: index - lastRevealedIndex)
        if revealFadeConfiguration.isEnabled {
            applyAttributes(in: revealRange, alphaMultiplier: revealFadeConfiguration.initialAlpha)
        } else {
            applyAttributes(in: revealRange, alphaMultiplier: nil)
        }

        textContentStorage.attributedString = workingAttributedString
        lastRevealedIndex = revealImmediateStructuralMarkers(
            in: workingAttributedString,
            from: originalAttributedString,
            startingAt: index
        )
        updateLayout()
        setNeedsDisplay()

        if revealFadeConfiguration.isEnabled {
            scheduleRevealFade(for: revealRange, generation: revealFadeGeneration)
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
}

private extension TextFlowView {
    static let commaCharacters: Set<unichar> = [0x002C, 0xFF0C, 0x3001]
    static let sentenceCharacters: Set<unichar> = [0x002E, 0x0021, 0x003F, 0x000A]
    static let idleRevealPollInterval: TimeInterval = 0.016
    static let defaultIdleRevealTimeout: TimeInterval = 0.30

    func resetStreamingState(clearTiming: Bool) {
        streamingRevealTask?.cancel()
        streamingRevealTask = nil
        deferredStreamingStartTask?.cancel()
        deferredStreamingStartTask = nil
        streamingProfile = nil
        pendingStreamingStartTime = nil
        cancelRevealFadeTasks()

        cachedPrefixHeightKey = (-1, 0)

        if clearTiming {
            lastStreamingUpdateTime = nil
            previousStreamingTargetLength = 0
            streamingIdleTimeout = Self.defaultIdleRevealTimeout
        }
    }

    func updateStreamCadence(now: TimeInterval) {
        lastStreamingUpdateTime = now
    }

    func installStreamingTarget(_ attributedString: NSAttributedString, visibleCharacterCount: Int) {
        cancelRevealFadeTasks()
        let clampedVisibleCount = min(max(0, visibleCharacterCount), attributedString.length)
        let workingString = NSMutableAttributedString(attributedString: attributedString)
        hideCharacters(
            in: NSRange(location: clampedVisibleCount, length: attributedString.length - clampedVisibleCount),
            within: workingString
        )
        let revealedCharacterCount = revealImmediateStructuralMarkers(
            in: workingString,
            from: attributedString,
            startingAt: clampedVisibleCount
        )

        originalAttributedString = NSAttributedString(attributedString: attributedString)
        workingAttributedString = workingString
        lastRevealedIndex = revealedCharacterCount
        textContentStorage.attributedString = workingString
        setNeedsLayout()
        setNeedsDisplay()
    }

    func cancelRevealFadeTasks() {
        revealFadeGeneration &+= 1
        for task in revealFadeTasks.values {
            task.cancel()
        }
        revealFadeTasks.removeAll()
    }

    func applyAttributes(in revealRange: NSRange, alphaMultiplier: CGFloat?) {
        guard let originalAttributedString,
              let workingAttributedString else {
            return
        }

        originalAttributedString.enumerateAttributes(in: revealRange) { attributes, range, _ in
            var resolvedAttributes = attributes
            if let alphaMultiplier {
                let baseColor = (attributes[.foregroundColor] as? UIColor) ?? .label
                resolvedAttributes[.foregroundColor] = baseColor.withAlphaComponent(baseColor.cgColor.alpha * alphaMultiplier)
            }
            workingAttributedString.setAttributes(resolvedAttributes, range: range)
        }
    }

    func scheduleRevealFade(for revealRange: NSRange, generation: Int) {
        let midpointAlpha = revealFadeConfiguration.initialAlpha + ((1 - revealFadeConfiguration.initialAlpha) * 0.5)
        let stepDelay = revealFadeConfiguration.duration / 2
        let taskID = UUID()

        let task = Task { @MainActor [weak self] in
            defer { self?.revealFadeTasks[taskID] = nil }

            if stepDelay > 0 {
                try? await Task.sleep(for: .seconds(stepDelay))
            }

            guard let self,
                  !Task.isCancelled,
                  self.revealFadeGeneration == generation else {
                return
            }

            self.applyAttributes(in: revealRange, alphaMultiplier: midpointAlpha)
            if let workingAttributedString = self.workingAttributedString {
                self.textContentStorage.attributedString = workingAttributedString
                self.setNeedsDisplay()
            }

            if stepDelay > 0 {
                try? await Task.sleep(for: .seconds(stepDelay))
            }

            guard !Task.isCancelled,
                  self.revealFadeGeneration == generation else {
                return
            }

            self.applyAttributes(in: revealRange, alphaMultiplier: nil)
            if let workingAttributedString = self.workingAttributedString {
                self.textContentStorage.attributedString = workingAttributedString
                self.setNeedsDisplay()
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
                    if idleSinceLastUpdate >= self.streamingIdleTimeout {
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
                    jitterMax: profile.jitterMax,
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

    func revealImmediateStructuralMarkers(
        in working: NSMutableAttributedString,
        from original: NSAttributedString,
        startingAt start: Int
    ) -> Int {
        guard start < working.length else { return working.length }

        var revealedCharacterCount = start
        while revealedCharacterCount < working.length {
            var markerRange = NSRange()
            let marker = original.attribute(
                .structuralMarker,
                at: revealedCharacterCount,
                longestEffectiveRange: &markerRange,
                in: NSRange(location: 0, length: working.length)
            )
            guard marker != nil,
                  markerRange.location == revealedCharacterCount
            else {
                break
            }

            original.enumerateAttributes(in: markerRange) { attributes, range, _ in
                working.setAttributes(attributes, range: range)
            }
            revealedCharacterCount = markerRange.location + markerRange.length
        }

        return revealedCharacterCount
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
        jitterMax: TimeInterval,
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

        let jitter = jitterMax > 0 ? Double.random(in: 0...jitterMax) : 0
        return baseDuration + extraDuration + jitter
    }

    func computeFullLayoutHeight() -> CGFloat {
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
        return maxY
    }

    func updateLayout() {
        textContainer.size = CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)

        let height: CGFloat
        if let originalAttributedString {
            let total = originalAttributedString.length
            if lastRevealedIndex == 0 {
                height = 0
            } else if lastRevealedIndex >= total {
                height = computeFullLayoutHeight()
            } else {
                height = visiblePrefixHeight(forWidth: bounds.width)
            }
        } else {
            var maxY = computeFullLayoutHeight()
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
            height = maxY
        }

        heightConstraint?.constant = ceil(height)
        invalidateIntrinsicContentSize()
    }

    func visiblePrefixHeight(forWidth width: CGFloat) -> CGFloat {
        guard width > 0,
              lastRevealedIndex > 0,
              let originalAttributedString,
              lastRevealedIndex < originalAttributedString.length
        else {
            return 0
        }

        let key = (revealIndex: lastRevealedIndex, width: width)
        if key == cachedPrefixHeightKey {
            return cachedPrefixHeight
        }

        let visiblePrefix = originalAttributedString.attributedSubstring(
            from: NSRange(location: 0, length: lastRevealedIndex)
        )
        let boundingSize = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let height = ceil(
            visiblePrefix.boundingRect(
                with: boundingSize,
                options: [.usesLineFragmentOrigin],
                context: nil
            ).height
        )

        cachedPrefixHeight = height
        cachedPrefixHeightKey = key
        return height
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
