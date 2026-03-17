import UIKit

struct TextFlowRevealController {
    struct StreamingProfile {
        var charsPerStep: Int
        var baseDuration: TimeInterval
        var commaPause: TimeInterval
        var jitterMax: TimeInterval
        var sentencePause: TimeInterval
    }

    struct RevealFadeConfiguration {
        var initialAlpha: CGFloat = 0.2
        var duration: TimeInterval = 0.08

        var isEnabled: Bool {
            initialAlpha < 1 && duration > 0
        }
    }

    private(set) var lastRevealedIndex = 0
    private(set) var originalAttributedString: NSAttributedString?
    var workingAttributedString: NSMutableAttributedString?
    var streamingProfile: StreamingProfile?
    var pendingStreamingStartTime: TimeInterval?
    var lastStreamingUpdateTime: TimeInterval?
    var previousStreamingTargetLength = 0
    var streamingIdleTimeout: TimeInterval = 0.30
    var revealFadeConfiguration = RevealFadeConfiguration()
    var revealFadeGeneration = 0

    static let commaCharacters: Set<unichar> = [0x002C, 0xFF0C, 0x3001]
    static let sentenceCharacters: Set<unichar> = [0x002E, 0x0021, 0x003F, 0x000A]
    static let idleRevealPollInterval: TimeInterval = 0.016
    static let defaultIdleRevealTimeout: TimeInterval = 0.30

    var totalCharacterCount: Int { originalAttributedString?.length ?? 0 }

    mutating func setLastRevealedIndex(_ index: Int) {
        lastRevealedIndex = index
    }

    mutating func setOriginalAttributedString(_ value: NSAttributedString?) {
        originalAttributedString = value
    }

    mutating func resetStreamingState(clearTiming: Bool) {
        streamingProfile = nil
        pendingStreamingStartTime = nil
        revealFadeGeneration &+= 1

        if clearTiming {
            lastStreamingUpdateTime = nil
            previousStreamingTargetLength = 0
            streamingIdleTimeout = Self.defaultIdleRevealTimeout
        }
    }

    mutating func updateStreamCadence(now: TimeInterval) {
        lastStreamingUpdateTime = now
    }

    mutating func installStreamingTarget(
        _ attributedString: NSAttributedString,
        visibleCharacterCount: Int
    ) -> NSMutableAttributedString {
        revealFadeGeneration &+= 1
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
        return workingString
    }

    mutating func applyReveal(
        upTo index: Int
    ) -> (revealRange: NSRange, newRevealedIndex: Int)? {
        guard let originalAttributedString,
              let workingAttributedString,
              index > lastRevealedIndex,
              index <= originalAttributedString.length else { return nil }

        let revealRange = NSRange(location: lastRevealedIndex, length: index - lastRevealedIndex)
        if revealFadeConfiguration.isEnabled {
            applyAttributes(in: revealRange, alphaMultiplier: revealFadeConfiguration.initialAlpha)
        } else {
            applyAttributes(in: revealRange, alphaMultiplier: nil)
        }

        let newRevealedIndex = revealImmediateStructuralMarkers(
            in: workingAttributedString,
            from: originalAttributedString,
            startingAt: index
        )
        lastRevealedIndex = newRevealedIndex
        return (revealRange, newRevealedIndex)
    }

    mutating func prepareForReveal(
        currentAttributedString: NSAttributedString?
    ) -> NSMutableAttributedString? {
        guard originalAttributedString == nil,
              let attributedString = currentAttributedString,
              attributedString.length > 0 else { return nil }

        originalAttributedString = NSAttributedString(attributedString: attributedString)
        let workingString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: workingString.length)
        workingString.addAttribute(.foregroundColor, value: UIColor.clear, range: fullRange)
        workingString.removeAttribute(.link, range: fullRange)

        workingAttributedString = workingString
        lastRevealedIndex = revealImmediateStructuralMarkers(
            in: workingString,
            from: attributedString,
            startingAt: 0
        )
        return workingString
    }

    mutating func finishReveal(
        currentAttributedStringLength: Int
    ) -> NSAttributedString? {
        if let originalAttributedString {
            let result = originalAttributedString
            lastRevealedIndex = originalAttributedString.length
            self.originalAttributedString = nil
            workingAttributedString = nil
            previousStreamingTargetLength = lastRevealedIndex
            return result
        }

        lastRevealedIndex = currentAttributedStringLength
        previousStreamingTargetLength = lastRevealedIndex
        return nil
    }

    func currentVisibleCharacterCount(currentStorageLength: Int) -> Int {
        if let originalAttributedString,
           let workingAttributedString,
           originalAttributedString.length == workingAttributedString.length {
            return lastRevealedIndex
        }

        return currentStorageLength
    }

    func currentVisiblePrefix(currentStorageAttributedString: NSAttributedString?) -> NSAttributedString {
        let visibleCharacterCount = currentVisibleCharacterCount(
            currentStorageLength: currentStorageAttributedString?.length ?? 0
        )

        if let originalAttributedString,
           visibleCharacterCount <= originalAttributedString.length {
            return originalAttributedString.attributedSubstring(
                from: NSRange(location: 0, length: visibleCharacterCount)
            )
        }

        guard let currentAttributedString = currentStorageAttributedString else {
            return NSAttributedString(string: "")
        }

        return currentAttributedString.attributedSubstring(
            from: NSRange(location: 0, length: min(visibleCharacterCount, currentAttributedString.length))
        )
    }

    func shouldAnimateStreamingUpdate(
        with attributedString: NSAttributedString,
        currentStorageAttributedString: NSAttributedString?
    ) -> Bool {
        let visiblePrefix = currentVisiblePrefix(currentStorageAttributedString: currentStorageAttributedString)
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

    func midpointAlpha() -> CGFloat {
        revealFadeConfiguration.initialAlpha + ((1 - revealFadeConfiguration.initialAlpha) * 0.5)
    }

    func fadeStepDelay() -> TimeInterval {
        revealFadeConfiguration.duration / 2
    }
}
