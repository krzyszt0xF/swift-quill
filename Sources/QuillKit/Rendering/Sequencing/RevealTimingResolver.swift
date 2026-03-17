import Foundation

enum RevealTimingResolver {
    static func resolveTiming(
        pendingTaskCount: Int,
        typewriterConfiguration: TypewriterConfiguration,
        performanceProfile: PerformanceProfile,
        fixedTimingOverride: RevealSequencer.ResolvedTiming?
    ) -> RevealSequencer.ResolvedTiming {
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

        return RevealSequencer.ResolvedTiming(
            charsPerStep: profileTiming.charsPerStep,
            baseDuration: profileTiming.baseDuration * multiplier,
            elementGapDuration: profileTiming.elementGapDuration * multiplier,
            commaPause: typewriterConfiguration.commaPause,
            sentencePause: typewriterConfiguration.sentencePause,
            jitterMax: typewriterConfiguration.jitterMax
        )
    }

    static func resolveTextTiming(
        _ timing: RevealSequencer.ResolvedTiming,
        totalCharacters: Int,
        minimumTextAnimationWindow: TimeInterval
    ) -> RevealSequencer.ResolvedTiming {
        guard minimumTextAnimationWindow > 0, totalCharacters > 0 else {
            return timing
        }

        let requiredSteps = max(1, Int(ceil(minimumTextAnimationWindow / timing.baseDuration)))
        let reducedCharsPerStep = max(1, Int(floor(Double(totalCharacters) / Double(requiredSteps))))
        let effectiveCharsPerStep = min(timing.charsPerStep, reducedCharsPerStep)
        let effectiveStepCount = max(1, Int(ceil(Double(totalCharacters) / Double(effectiveCharsPerStep))))
        let minimumBaseDuration = minimumTextAnimationWindow / Double(effectiveStepCount)
        let effectiveBaseDuration = max(timing.baseDuration, minimumBaseDuration)
        let jitterScale = timing.baseDuration > 0 ? timing.jitterMax / timing.baseDuration : 0
        let effectiveJitterMax = min(
            0.018,
            max(timing.jitterMax, effectiveBaseDuration * jitterScale)
        )

        return RevealSequencer.ResolvedTiming(
            charsPerStep: effectiveCharsPerStep,
            baseDuration: effectiveBaseDuration,
            elementGapDuration: timing.elementGapDuration,
            commaPause: timing.commaPause,
            sentencePause: timing.sentencePause,
            jitterMax: effectiveJitterMax
        )
    }

    static func calculateDelay(
        originalString: NSAttributedString?,
        from startIndex: Int,
        to endIndex: Int,
        timing: RevealSequencer.ResolvedTiming
    ) -> TimeInterval {
        var extraDelay: TimeInterval = 0

        if let original = originalString {
            let nsString = original.string as NSString
            for i in startIndex..<endIndex where i < nsString.length {
                let char = nsString.character(at: i)
                if sentenceEnders.contains(char) {
                    extraDelay = max(extraDelay, timing.sentencePause)
                } else if commaChars.contains(char) {
                    extraDelay = max(extraDelay, timing.commaPause)
                }
            }
        }

        let jitter = timing.jitterMax > 0 ? Double.random(in: 0...timing.jitterMax) : 0
        return timing.baseDuration + extraDelay + jitter
    }

    private static let commaChars: Set<unichar> = [0x002C, 0xFF0C, 0x3001]
    private static let sentenceEnders: Set<unichar> = [0x002E, 0x0021, 0x003F, 0x000A]
}
