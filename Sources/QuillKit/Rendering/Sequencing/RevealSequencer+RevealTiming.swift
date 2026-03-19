import Foundation

struct RevealTiming: Equatable, Sendable {
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

extension RevealTiming {
    func delay(
        from startIndex: Int,
        to endIndex: Int,
        originalString: NSAttributedString?) -> TimeInterval {
        var extraDelay: TimeInterval = 0

        if let original = originalString {
            let commaChars: Set<unichar> = [0x002C, 0xFF0C, 0x3001]
            let sentenceEnders: Set<unichar> = [0x002E, 0x0021, 0x003F, 0x000A]
            let nsString = original.string as NSString
            
            for i in startIndex..<endIndex where i < nsString.length {
                let char = nsString.character(at: i)
                if sentenceEnders.contains(char) {
                    extraDelay = max(extraDelay, sentencePause)
                } else if commaChars.contains(char) {
                    extraDelay = max(extraDelay, commaPause)
                }
            }
        }

        let jitter = jitterMax > 0 ? Double.random(in: 0...jitterMax) : 0
            
        return baseDuration + extraDelay + jitter
    }
    
    func next(totalCharacters: Int, minimumTextAnimationWindow: TimeInterval) -> Self {
        guard minimumTextAnimationWindow > 0, totalCharacters > 0 else {
            return self
        }

        let requiredSteps = max(1, Int(ceil(minimumTextAnimationWindow / baseDuration)))
        let reducedCharsPerStep = max(1, Int(floor(Double(totalCharacters) / Double(requiredSteps))))
        let effectiveCharsPerStep = min(charsPerStep, reducedCharsPerStep)
        let effectiveStepCount = max(1, Int(ceil(Double(totalCharacters) / Double(effectiveCharsPerStep))))
        let minimumBaseDuration = minimumTextAnimationWindow / Double(effectiveStepCount)
        let effectiveBaseDuration = max(baseDuration, minimumBaseDuration)
        let jitterScale = baseDuration > 0 ? jitterMax / baseDuration : 0
        let effectiveJitterMax = min(
            0.018,
            max(jitterMax, effectiveBaseDuration * jitterScale)
        )

        return Self(
            charsPerStep: effectiveCharsPerStep,
            baseDuration: effectiveBaseDuration,
            elementGapDuration: elementGapDuration,
            commaPause: commaPause,
            sentencePause: sentencePause,
            jitterMax: effectiveJitterMax)
    }
}

extension RevealTiming {
    static let live = Self(
        charsPerStep: 6,
        baseDuration: 0.012,
        elementGapDuration: 0.03,
        commaPause: 0.015,
        sentencePause: 0.045,
        jitterMax: 0.005)
    
    static let buffered = Self(
        charsPerStep: 4,
        baseDuration: 0.014,
        elementGapDuration: 0.04,
        commaPause: 0.03,
        sentencePause: 0.08,
        jitterMax: 0.005)
    
    init(
        pendingTaskCount: Int,
        typewriterConfiguration: TypewriterConfiguration,
        performanceProfile: PerformanceProfile) {
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
            
            self = Self(
                charsPerStep: profileTiming.charsPerStep,
                baseDuration: profileTiming.baseDuration * multiplier,
                elementGapDuration: profileTiming.elementGapDuration * multiplier,
                commaPause: typewriterConfiguration.commaPause,
                sentencePause: typewriterConfiguration.sentencePause,
                jitterMax: typewriterConfiguration.jitterMax)
        }
}
